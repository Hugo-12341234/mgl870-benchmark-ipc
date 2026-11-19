param(
    [string]$SuiteId = (Get-Date -Format "yyyyMMdd-HHmmss"),
    [string]$OutputDirectory = "",
    [switch]$Quick
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repositoryRoot

$safeSuiteId = $SuiteId -replace "[^A-Za-z0-9_-]", "-"
if (-not $OutputDirectory) {
    $OutputDirectory = if ($Quick) { "pilot_$safeSuiteId" } else { "rerun_$safeSuiteId" }
}

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$targetDirectory = Join-Path $repositoryRoot (Join-Path "results" $OutputDirectory)
if (Test-Path -LiteralPath $targetDirectory) {
    $existingSummaries = @(
        Get-ChildItem -LiteralPath $targetDirectory -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -eq "k6_summary.json" -or $_.Name -like "k6*_results_run*.json" }
    )
    if ($existingSummaries.Count -gt 0) {
        throw "The result directory already contains benchmark summaries: $targetDirectory. Use a new SuiteId or OutputDirectory."
    }
}

$runs = if ($Quick) { 1 } else { 5 }
$skipBuild = $false

for ($run = 1; $run -le $runs; $run++) {
    foreach ($workload in @("individual", "batch")) {
        $arguments = @{
            Workload = $workload
            Run = $run
            SuiteId = $safeSuiteId
            OutputDirectory = $OutputDirectory
        }
        if ($Quick) {
            $arguments.Quick = $true
        }
        if ($skipBuild) {
            $arguments.SkipBuild = $true
        }
        & (Join-Path $PSScriptRoot "run_benchmark.ps1") @arguments
        $skipBuild = $true
        Start-Sleep -Seconds 15
    }
}

& (Join-Path $PSScriptRoot "summarize_results.ps1") -OutputDirectory $OutputDirectory

$screenshotsDirectory = Join-Path $targetDirectory "screenshots"
New-Item -ItemType Directory -Force -Path (Join-Path $screenshotsDirectory "individual") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $screenshotsDirectory "batch") | Out-Null

Write-Host ""
Write-Host "Benchmark suite complete."
Write-Host "Results: results/$OutputDirectory"
Write-Host "Grafana: http://localhost:3000"
Write-Host "Prometheus: http://localhost:9090"
Write-Host "The observability stack remains running so representative screenshots can be captured."
