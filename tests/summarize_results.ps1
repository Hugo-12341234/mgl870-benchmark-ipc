param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
if ($OutputDirectory -match "\.\." -or [System.IO.Path]::IsPathRooted($OutputDirectory)) {
    throw "OutputDirectory must be a relative directory below results/."
}
$resultDirectory = Join-Path $repositoryRoot (Join-Path "results" $OutputDirectory)
$protocols = @("rest", "graphql", "jsonrpc", "grpc")
$rows = @()

$files = Get-ChildItem -LiteralPath $resultDirectory -Filter "k6*_results_run*.json" | Sort-Object Name
foreach ($file in $files) {
    $isBatch = $file.Name -like "k6_batch_*"
    $workload = if ($isBatch) { "batch" } else { "individual" }
    $metricPrefix = if ($isBatch) { "batch_protocol" } else { "protocol" }
    if ($file.Name -notmatch "run(\d+)") {
        continue
    }
    $run = [int]$Matches[1]
    $summary = Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
    $dropped = [long]$summary.metrics.dropped_iterations.values.count
    $iterations = [long]$summary.metrics.iterations.values.count

    foreach ($protocol in $protocols) {
        $durationKey = "${metricPrefix}_request_duration{protocol:$protocol}"
        $requestsKey = "${metricPrefix}_requests{protocol:$protocol}"
        $errorsKey = "${metricPrefix}_error_rate{protocol:$protocol}"
        $duration = $summary.metrics.PSObject.Properties[$durationKey].Value.values
        $requests = $summary.metrics.PSObject.Properties[$requestsKey].Value.values
        $errorRate = $summary.metrics.PSObject.Properties[$errorsKey].Value.values.rate
        $rows += [pscustomobject]@{
            workload = $workload
            run = $run
            protocol = $protocol
            requests = [long]$requests.count
            requests_per_second = [double]$requests.rate
            ticks_per_second = if ($isBatch) { 500 * [double]$requests.rate } else { [double]$requests.rate }
            avg_ms = [double]$duration.avg
            p50_ms = [double]$duration.'p(50)'
            p95_ms = [double]$duration.'p(95)'
            p99_ms = [double]$duration.'p(99)'
            error_rate = [double]$errorRate
            total_iterations = $iterations
            dropped_iterations = $dropped
            dropped_percent = 100 * $dropped / ($iterations + $dropped)
        }
    }
}

if ($rows.Count -eq 0) {
    throw "No rerun summaries were found in $resultDirectory."
}

$rows | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath (Join-Path $resultDirectory "per_run_results.csv")

$consolidated = $rows | Group-Object workload, protocol | ForEach-Object {
    $groupRows = $_.Group
    [pscustomobject]@{
        workload = $groupRows[0].workload
        protocol = $groupRows[0].protocol
        runs = $groupRows.Count
        mean_requests_per_second = ($groupRows | Measure-Object requests_per_second -Average).Average
        mean_ticks_per_second = ($groupRows | Measure-Object ticks_per_second -Average).Average
        mean_p50_ms = ($groupRows | Measure-Object p50_ms -Average).Average
        mean_p95_ms = ($groupRows | Measure-Object p95_ms -Average).Average
        mean_p99_ms = ($groupRows | Measure-Object p99_ms -Average).Average
        min_p99_ms = ($groupRows | Measure-Object p99_ms -Minimum).Minimum
        max_p99_ms = ($groupRows | Measure-Object p99_ms -Maximum).Maximum
        mean_error_rate = ($groupRows | Measure-Object error_rate -Average).Average
    }
}
$consolidated | Sort-Object workload, protocol | Export-Csv -NoTypeInformation -Encoding utf8 -LiteralPath (Join-Path $resultDirectory "consolidated_results.csv")

$markdown = @(
    "# Consolidated benchmark results",
    "",
    "| Workload | Protocol | Runs | Mean req/s | Mean ticks/s | Mean p50 (ms) | Mean p95 (ms) | Mean p99 (ms) | Min-max p99 (ms) | Error rate |",
    "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |"
)
foreach ($row in ($consolidated | Sort-Object workload, protocol)) {
    $markdown += "| $($row.workload) | $($row.protocol) | $($row.runs) | $([math]::Round($row.mean_requests_per_second, 1)) | $([math]::Round($row.mean_ticks_per_second, 1)) | $([math]::Round($row.mean_p50_ms, 2)) | $([math]::Round($row.mean_p95_ms, 2)) | $([math]::Round($row.mean_p99_ms, 2)) | $([math]::Round($row.min_p99_ms, 2))-$([math]::Round($row.max_p99_ms, 2)) | $([math]::Round($row.mean_error_rate, 6)) |"
}
$markdown | Set-Content -Encoding utf8 -LiteralPath (Join-Path $resultDirectory "consolidated_results.md")

$representatives = @()
foreach ($workloadGroup in ($rows | Group-Object workload)) {
    $runScores = @($workloadGroup.Group | Group-Object run | ForEach-Object {
        [pscustomobject]@{
            run = [int]$_.Name
            mean_p99_ms = ($_.Group | Measure-Object p99_ms -Average).Average
        }
    } | Sort-Object run)
    $sortedScores = @($runScores.mean_p99_ms | Sort-Object)
    $middle = [int][math]::Floor($sortedScores.Count / 2)
    $medianMeanP99 = if ($sortedScores.Count % 2 -eq 1) {
        [double]$sortedScores[$middle]
    } else {
        ([double]$sortedScores[$middle - 1] + [double]$sortedScores[$middle]) / 2
    }
    $selected = $runScores | Sort-Object @{ Expression = { [math]::Abs($_.mean_p99_ms - $medianMeanP99) } }, run | Select-Object -First 1
    $manifestPattern = if ($workloadGroup.Name -eq "batch") {
        "manifest_batch_run$($selected.run).json"
    } else {
        "manifest_individual_run$($selected.run).json"
    }
    $manifestPath = Join-Path $resultDirectory $manifestPattern
    $testId = if (Test-Path -LiteralPath $manifestPath) {
        (Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json).test_id
    } else {
        "unavailable"
    }
    $representatives += [pscustomobject]@{
        workload = $workloadGroup.Name
        run = $selected.run
        test_id = $testId
        mean_p99_ms = $selected.mean_p99_ms
        median_of_run_mean_p99_ms = $medianMeanP99
    }
}

$representativeMarkdown = @(
    "# Representative runs for Grafana captures",
    "",
    "Selection rule: for each workload, choose the run whose mean p99 across the four protocols is closest to the median of the run-level mean p99 values.",
    "",
    "| Workload | Selected run | Grafana testid | Run mean p99 (ms) | Median run mean p99 (ms) |",
    "| --- | ---: | --- | ---: | ---: |"
)
foreach ($representative in ($representatives | Sort-Object workload)) {
    $representativeMarkdown += "| $($representative.workload) | $($representative.run) | ``$($representative.test_id)`` | $([math]::Round($representative.mean_p99_ms, 3)) | $([math]::Round($representative.median_of_run_mean_p99_ms, 3)) |"
}
$representativeMarkdown | Set-Content -Encoding utf8 -LiteralPath (Join-Path $resultDirectory "representative_runs.md")

Write-Host "Consolidated results written to $resultDirectory"
$consolidated | Sort-Object workload, protocol | Format-Table -AutoSize
Write-Host ""
Write-Host "Representative runs for Grafana captures:"
$representatives | Sort-Object workload | Format-Table -AutoSize
