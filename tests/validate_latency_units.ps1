$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $repositoryRoot

Write-Host "Starting an isolated Prometheus instance..."
docker compose up -d --no-deps prometheus

try {
    Write-Host "Running the synthetic k6 unit probe (1000 ms vs unitless 1000)..."
    docker compose run --rm --no-deps `
        -e K6_PROMETHEUS_RW_PUSH_INTERVAL=1s `
        k6-single `
        run `
        -o experimental-prometheus-rw `
        /scripts/latency_unit_validation.js

    Start-Sleep -Seconds 2

    Write-Host ""
    Write-Host "k6 summary values (milliseconds for the timed Trend):"
    $summary = Get-Content -Raw -LiteralPath "results/latency_unit_validation_summary.json" | ConvertFrom-Json
    $timedSummary = $summary.metrics.latency_unit_validation_duration.values
    $plainSummary = $summary.metrics.latency_unit_validation_plain.values
    Write-Host ("  timed p95: {0}" -f $timedSummary.'p(95)')
    Write-Host ("  plain p95: {0}" -f $plainSummary.'p(95)')

    Write-Host ""
    Write-Host "Raw Prometheus p99 gauges:"
    Write-Host "  timed Trend:"
    docker compose exec -T prometheus `
        promtool query instant http://localhost:9090 `
        "k6_latency_unit_validation_duration_p99"
    Write-Host "  unitless Trend:"
    docker compose exec -T prometheus `
        promtool query instant http://localhost:9090 `
        "k6_latency_unit_validation_plain_p99"

    Write-Host ""
    Write-Host "Expected interpretation: timed=1 second; unitless=1000."
}
finally {
    Write-Host "Stopping Prometheus while preserving the validation volume..."
    docker compose stop prometheus
}
