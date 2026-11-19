param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("individual", "batch")]
    [string]$Workload,

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 99)]
    [int]$Run,

    [Parameter(Mandatory = $true)]
    [string]$SuiteId,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [switch]$Quick,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repositoryRoot

if ($OutputDirectory -match "\.\." -or [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    throw "OutputDirectory must be a relative directory below results/."
}

$safeSuiteId = $SuiteId -replace "[^A-Za-z0-9_-]", "-"
$testId = "${safeSuiteId}-${Workload}-run${Run}"
$suiteDirectory = Join-Path $repositoryRoot (Join-Path "results" $OutputDirectory)
$resultDirectory = Join-Path $suiteDirectory (Join-Path $Workload "run_$Run")
New-Item -ItemType Directory -Force -Path $resultDirectory | Out-Null

$resultName = "k6_summary.json"
$telemetryName = "prometheus.json"
$manifestName = "manifest.json"
$relativeResultPath = ($OutputDirectory.TrimEnd("/", "\") + "/$Workload/run_$Run/$resultName").Replace("\", "/")

function Assert-LastExitCode {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        throw "$Operation failed with exit code $LASTEXITCODE."
    }
}

function Wait-TcpPort {
    param(
        [string]$TargetHost,
        [int]$Port,
        [int]$TimeoutSeconds = 120
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        $client = New-Object System.Net.Sockets.TcpClient
        try {
            $task = $client.ConnectAsync($TargetHost, $Port)
            if ($task.Wait(1000) -and $client.Connected) {
                return
            }
        }
        catch {
        }
        finally {
            $client.Dispose()
        }
        Start-Sleep -Seconds 2
    }
    throw "Timed out waiting for ${TargetHost}:$Port."
}

Write-Host "Preparing Docker environment for $testId..."
if ($SkipBuild) {
    docker compose up -d
} else {
    docker compose up -d --build
}
Assert-LastExitCode -Operation "docker compose up"

docker compose restart server-rest server-graphql server-jsonrpc server-grpc | Out-Host
Assert-LastExitCode -Operation "server restart"

foreach ($port in @(8081, 8082, 8083, 50051, 9090, 3000)) {
    Wait-TcpPort -TargetHost "localhost" -Port $port
}
Start-Sleep -Seconds 5

$service = if ($Workload -eq "batch") { "k6-batch" } else { "k6-single" }
$startTime = [DateTimeOffset]::UtcNow
$startEpoch = $startTime.ToUnixTimeSeconds()

$composeArguments = @(
    "compose", "run", "--rm",
    "-e", "TEST_ID=$testId",
    "-e", "RESULT_PATH=$relativeResultPath"
)
if ($Quick) {
    $composeArguments += @("-e", "QUICK_TEST=true")
}
$composeArguments += $service

Write-Host "Running $Workload benchmark $Run (testid=$testId)..."
& docker @composeArguments
$k6ExitCode = $LASTEXITCODE
if ($k6ExitCode -ne 0 -and $k6ExitCode -ne 99) {
    throw "k6 failed with unexpected exit code $k6ExitCode."
}

Start-Sleep -Seconds 7
$endTime = [DateTimeOffset]::UtcNow
$endEpoch = $endTime.ToUnixTimeSeconds()
$summaryPath = Join-Path $resultDirectory $resultName
if (-not (Test-Path -LiteralPath $summaryPath)) {
    throw "Expected k6 summary was not created: $summaryPath"
}

$telemetryPath = Join-Path $resultDirectory $telemetryName
& (Join-Path $PSScriptRoot "export_prometheus_run.ps1") `
    -Workload $Workload `
    -TestId $testId `
    -StartEpoch $startEpoch `
    -EndEpoch $endEpoch `
    -OutputPath $telemetryPath

$telemetry = Get-Content -Raw -LiteralPath $telemetryPath | ConvertFrom-Json
$requiredTelemetry = @(
    "latency_p50",
    "latency_p95",
    "latency_p99",
    "requests_per_second",
    "error_rate",
    "active_vus",
    "server_cpu",
    "load_generator_cpu",
    "server_memory",
    "load_generator_memory",
    "network_transmit",
    "network_receive"
)
$telemetrySeries = [ordered]@{}
foreach ($queryName in $telemetry.queries.PSObject.Properties.Name) {
    $telemetrySeries[$queryName] = @($telemetry.queries.$queryName.data.result).Count
}
foreach ($queryName in $requiredTelemetry) {
    if (-not $telemetrySeries.Contains($queryName) -or $telemetrySeries[$queryName] -eq 0) {
        throw "Prometheus export contains no series for required query '$queryName'."
    }
}

$summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
$metricPrefix = if ($Workload -eq "batch") { "batch_protocol" } else { "protocol" }
$protocols = @("rest", "graphql", "jsonrpc", "grpc")
$table = @()
foreach ($protocol in $protocols) {
    $durationKey = "${metricPrefix}_request_duration{protocol:$protocol}"
    $requestsKey = "${metricPrefix}_requests{protocol:$protocol}"
    $errorsKey = "${metricPrefix}_error_rate{protocol:$protocol}"
    $durationMetric = $summary.metrics.PSObject.Properties[$durationKey].Value
    $requestsMetric = $summary.metrics.PSObject.Properties[$requestsKey].Value
    $errorsMetric = $summary.metrics.PSObject.Properties[$errorsKey].Value
    if ($null -eq $durationMetric -or $null -eq $requestsMetric -or $null -eq $errorsMetric) {
        throw "Missing per-protocol summary metrics for $protocol."
    }
    $table += [pscustomobject]@{
        protocol = $protocol
        requests = [long]$requestsMetric.values.count
        p50_ms = [math]::Round([double]$durationMetric.values.'p(50)', 3)
        p95_ms = [math]::Round([double]$durationMetric.values.'p(95)', 3)
        p99_ms = [math]::Round([double]$durationMetric.values.'p(99)', 3)
        error_rate = [double]$errorsMetric.values.rate
    }
}

$failedChecks = [long]$summary.metrics.checks.values.fails
if ($failedChecks -ne 0) {
    throw "The run produced $failedChecks failed semantic checks."
}

$processor = Get-CimInstance Win32_Processor | Select-Object -First 1
$computer = Get-CimInstance Win32_ComputerSystem
$operatingSystem = Get-CimInstance Win32_OperatingSystem
$manifest = [ordered]@{
    schema_version = 1
    suite_id = $safeSuiteId
    test_id = $testId
    workload = $Workload
    run = $Run
    quick_test = [bool]$Quick
    start_utc = $startTime.ToString("o")
    end_utc = $endTime.ToString("o")
    k6_exit_code = $k6ExitCode
    semantic_check_failures = $failedChecks
    telemetry_series = $telemetrySeries
    git_commit = (git rev-parse HEAD).Trim()
    git_status = @((git status --short))
    docker_server_version = (docker version --format '{{.Server.Version}}').Trim()
    host = [ordered]@{
        os = $operatingSystem.Caption
        os_version = $operatingSystem.Version
        cpu = $processor.Name
        logical_processors = $computer.NumberOfLogicalProcessors
        memory_bytes = [long]$computer.TotalPhysicalMemory
    }
    artifacts = [ordered]@{
        k6_summary = $resultName
        prometheus_export = $telemetryName
    }
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $resultDirectory $manifestName)

Write-Host ""
Write-Host "Run completed. Per-protocol summary:"
$table | Format-Table -AutoSize
Write-Host "Artifacts: $resultDirectory"
if ($k6ExitCode -eq 99) {
    Write-Host "k6 exit code 99 records the expected saturation-threshold violation."
}
