param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("individual", "batch")]
    [string]$Workload,

    [Parameter(Mandatory = $true)]
    [string]$TestId,

    [Parameter(Mandatory = $true)]
    [long]$StartEpoch,

    [Parameter(Mandatory = $true)]
    [long]$EndEpoch,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$prometheusUrl = "http://localhost:9090"
$metricPrefix = if ($Workload -eq "batch") { "batch_protocol" } else { "protocol" }
$escapedTestId = $TestId.Replace('"', '\"')

$queries = [ordered]@{
    latency_p50 = "k6_${metricPrefix}_request_duration_p50{testid=`"$escapedTestId`"}"
    latency_p95 = "k6_${metricPrefix}_request_duration_p95{testid=`"$escapedTestId`"}"
    latency_p99 = "k6_${metricPrefix}_request_duration_p99{testid=`"$escapedTestId`"}"
    requests_per_second = "sum by (protocol) (rate(k6_${metricPrefix}_requests_total{testid=`"$escapedTestId`"}[1m]))"
    error_rate = "k6_${metricPrefix}_error_rate_rate{testid=`"$escapedTestId`"}"
    dropped_iterations_per_second = "sum by (scenario) (rate(k6_dropped_iterations_total{testid=`"$escapedTestId`"}[1m]))"
    active_vus = "k6_vus{testid=`"$escapedTestId`"}"
    server_cpu = 'rate(docker_container_cpu_usage_seconds_total{container_label_com_docker_compose_service=~"server-.*"}[1m])'
    load_generator_cpu = 'rate(docker_container_cpu_usage_seconds_total{container_label_com_docker_compose_service=~"k6-.*"}[1m])'
    server_memory = 'docker_container_memory_usage_bytes{container_label_com_docker_compose_service=~"server-.*"}'
    load_generator_memory = 'docker_container_memory_usage_bytes{container_label_com_docker_compose_service=~"k6-.*"}'
    network_transmit = 'rate(docker_container_network_transmit_bytes_total{container_label_com_docker_compose_service=~"server-.*"}[1m])'
    network_receive = 'rate(docker_container_network_receive_bytes_total{container_label_com_docker_compose_service=~"server-.*"}[1m])'
}

function Invoke-PrometheusRangeQuery {
    param([string]$Query)

    $encodedQuery = [Uri]::EscapeDataString($Query)
    $uri = "$prometheusUrl/api/v1/query_range?query=$encodedQuery&start=$StartEpoch&end=$EndEpoch&step=5"
    $response = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 60
    if ($response.status -ne "success") {
        throw "Prometheus query failed: $Query"
    }
    return $response.data
}

$exportedQueries = [ordered]@{}
foreach ($entry in $queries.GetEnumerator()) {
    $exportedQueries[$entry.Key] = [ordered]@{
        query = $entry.Value
        data = Invoke-PrometheusRangeQuery -Query $entry.Value
    }
}

$document = [ordered]@{
    schema_version = 1
    test_id = $TestId
    workload = $Workload
    start_epoch = $StartEpoch
    end_epoch = $EndEpoch
    step_seconds = 5
    latency_unit = "seconds"
    queries = $exportedQueries
}

$parent = Split-Path -Parent $OutputPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}
$document | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 -LiteralPath $OutputPath
Write-Host "Prometheus telemetry exported to $OutputPath"
