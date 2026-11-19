param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,
    [int]$ExpectedRuns = 5
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ($OutputDirectory -match "\.\." -or [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    throw "OutputDirectory must be a relative directory below results/."
}

$suiteDirectory = Join-Path $repositoryRoot (Join-Path "results" $OutputDirectory)
$summaryDirectory = Join-Path $suiteDirectory "summary"
if (-not (Test-Path -LiteralPath $suiteDirectory)) {
    throw "Benchmark suite not found: $suiteDirectory"
}
New-Item -ItemType Directory -Force -Path $summaryDirectory | Out-Null

$protocols = @("rest", "graphql", "jsonrpc", "grpc")
$requiredQueries = @(
    "latency_p50", "latency_p95", "latency_p99", "requests_per_second",
    "error_rate", "active_vus", "server_cpu", "load_generator_cpu",
    "server_memory", "load_generator_memory", "network_transmit", "network_receive"
)
$checks = @()
$runReports = @()
$manifests = @()

function Add-ValidationCheck {
    param([string]$Name, [bool]$Passed, [string]$Detail)
    $script:checks += [pscustomobject]@{ name = $Name; passed = $Passed; detail = $Detail }
}

foreach ($workload in @("individual", "batch")) {
    for ($run = 1; $run -le $ExpectedRuns; $run++) {
        $runDirectory = Join-Path $suiteDirectory (Join-Path $workload "run_$run")
        $summaryPath = Join-Path $runDirectory "k6_summary.json"
        $manifestPath = Join-Path $runDirectory "manifest.json"
        $telemetryPath = Join-Path $runDirectory "prometheus.json"
        $artifactsExist = (Test-Path -LiteralPath $summaryPath) -and
            (Test-Path -LiteralPath $manifestPath) -and
            (Test-Path -LiteralPath $telemetryPath)
        Add-ValidationCheck "$workload run $run artifacts" $artifactsExist $runDirectory
        if (-not $artifactsExist) { continue }

        $summary = Get-Content -Raw -LiteralPath $summaryPath | ConvertFrom-Json
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        $telemetry = Get-Content -Raw -LiteralPath $telemetryPath | ConvertFrom-Json
        $manifests += $manifest
        $metricPrefix = if ($workload -eq "batch") { "batch_protocol" } else { "protocol" }

        $failedChecks = [long]$summary.metrics.checks.values.fails
        Add-ValidationCheck "$workload run $run semantic checks" ($failedChecks -eq 0) "failed=$failedChecks"
        Add-ValidationCheck "$workload run $run official profile" (-not [bool]$manifest.quick_test) "quick_test=$($manifest.quick_test)"
        Add-ValidationCheck "$workload run $run manifest identity" ($manifest.workload -eq $workload -and [int]$manifest.run -eq $run) "test_id=$($manifest.test_id)"

        $protocolMetricsComplete = $true
        $nonzeroErrors = @()
        foreach ($protocol in $protocols) {
            $durationKey = "${metricPrefix}_request_duration{protocol:$protocol}"
            $requestsKey = "${metricPrefix}_requests{protocol:$protocol}"
            $errorsKey = "${metricPrefix}_error_rate{protocol:$protocol}"
            $durationMetric = $summary.metrics.PSObject.Properties[$durationKey]
            $requestsMetric = $summary.metrics.PSObject.Properties[$requestsKey]
            $errorsMetric = $summary.metrics.PSObject.Properties[$errorsKey]
            if ($null -eq $durationMetric -or $null -eq $requestsMetric -or $null -eq $errorsMetric) {
                $protocolMetricsComplete = $false
                continue
            }
            if ([double]$errorsMetric.Value.values.rate -ne 0) {
                $nonzeroErrors += $protocol
            }
        }
        Add-ValidationCheck "$workload run $run per-protocol metrics" $protocolMetricsComplete "four protocols expected"
        Add-ValidationCheck "$workload run $run error rates" ($nonzeroErrors.Count -eq 0) ("nonzero=" + ($nonzeroErrors -join ","))

        $missingTelemetry = @()
        foreach ($queryName in $requiredQueries) {
            $property = $telemetry.queries.PSObject.Properties[$queryName]
            if ($null -eq $property -or @($property.Value.data.result).Count -eq 0) {
                $missingTelemetry += $queryName
            }
        }
        Add-ValidationCheck "$workload run $run telemetry" ($missingTelemetry.Count -eq 0) ("missing=" + ($missingTelemetry -join ","))

        $iterations = [long]$summary.metrics.iterations.values.count
        $dropped = [long]$summary.metrics.dropped_iterations.values.count
        $droppedPercent = 100 * $dropped / ($iterations + $dropped)
        $runReports += [pscustomobject]@{
            workload = $workload
            run = $run
            test_id = [string]$manifest.test_id
            duration_seconds = [math]::Round([double]$summary.state.testRunDurationMs / 1000, 3)
            iterations = $iterations
            dropped_iterations = $dropped
            dropped_percent = $droppedPercent
            semantic_failures = $failedChecks
            application_error_protocols = $nonzeroErrors.Count
            telemetry_queries_missing = $missingTelemetry.Count
        }
    }
}

$expectedManifestCount = 2 * $ExpectedRuns
Add-ValidationCheck "manifest count" ($manifests.Count -eq $expectedManifestCount) "found=$($manifests.Count), expected=$expectedManifestCount"
$uniqueTestIds = @($manifests.test_id | Sort-Object -Unique)
Add-ValidationCheck "unique test IDs" ($uniqueTestIds.Count -eq $manifests.Count) "unique=$($uniqueTestIds.Count)"
$commits = @($manifests.git_commit | Sort-Object -Unique)
Add-ValidationCheck "single Git commit" ($commits.Count -eq 1) ($commits -join ",")
$dockerVersions = @($manifests.docker_server_version | Sort-Object -Unique)
Add-ValidationCheck "single Docker version" ($dockerVersions.Count -eq 1) ($dockerVersions -join ",")
$hosts = @($manifests | ForEach-Object { "$($_.host.os)|$($_.host.os_version)|$($_.host.cpu)|$($_.host.logical_processors)|$($_.host.memory_bytes)" } | Sort-Object -Unique)
Add-ValidationCheck "single host configuration" ($hosts.Count -eq 1) ($hosts -join ",")

$failed = @($checks | Where-Object { -not $_.passed })
$document = [ordered]@{
    schema_version = 1
    suite = $OutputDirectory
    generated_utc = [DateTimeOffset]::UtcNow.ToString("o")
    expected_runs_per_workload = $ExpectedRuns
    status = if ($failed.Count -eq 0) { "PASS" } else { "FAIL" }
    checks_total = $checks.Count
    checks_failed = $failed.Count
    checks = $checks
    runs = $runReports
}
$document | ConvertTo-Json -Depth 20 | Set-Content -Encoding utf8 -LiteralPath (Join-Path $summaryDirectory "validation_report.json")

$markdown = @(
    "# Benchmark suite validation",
    "",
    "- Suite: ``$OutputDirectory``",
    "- Status: **$($document.status)**",
    "- Checks: $($document.checks_total - $document.checks_failed)/$($document.checks_total) passed",
    "- Runs: $($runReports.Count)/$expectedManifestCount present",
    "- Git commit: ``$($commits -join ',')``",
    "- Docker server: ``$($dockerVersions -join ',')``",
    "",
    "| Workload | Run | Duration (s) | Completed | Dropped | Dropped | Semantic failures | Error protocols | Missing telemetry |",
    "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
)
foreach ($row in ($runReports | Sort-Object workload, run)) {
    $markdown += "| $($row.workload) | $($row.run) | $($row.duration_seconds) | $($row.iterations) | $($row.dropped_iterations) | $([math]::Round($row.dropped_percent, 2))% | $($row.semantic_failures) | $($row.application_error_protocols) | $($row.telemetry_queries_missing) |"
}
if ($failed.Count -gt 0) {
    $markdown += @("", "## Failed checks", "")
    foreach ($failure in $failed) {
        $markdown += "- **$($failure.name):** $($failure.detail)"
    }
}
$markdown | Set-Content -Encoding utf8 -LiteralPath (Join-Path $summaryDirectory "validation_report.md")

Write-Host "Validation status: $($document.status) ($($document.checks_total - $document.checks_failed)/$($document.checks_total) checks passed)"
if ($failed.Count -gt 0) {
    throw "Benchmark suite validation failed. See $summaryDirectory/validation_report.md."
}
