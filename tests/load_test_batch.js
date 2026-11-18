import grpcModule from "k6/net/grpc";
import http from "k6/http";
import { check } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

const protocols = ["rest", "graphql", "jsonrpc", "grpc"];
const quickTest = __ENV.QUICK_TEST === "true";
const testId = __ENV.TEST_ID || "manual-batch";
const batchSize = 500;

const tick = {
  symbol: "SHOP",
  price: 115.42,
  volume: 100,
  timestamp: 1700000000,
};
const ticks = Array.from({ length: batchSize }, () => tick);
const jsonHeaders = { "Content-Type": "application/json" };
const restUrl = __ENV.BATCH_REST_URL || "http://localhost:8081/api/ticks/batch";
const graphqlUrl =
  __ENV.BATCH_GRAPHQL_URL || "http://localhost:8082/graphql";
const jsonrpcUrl =
  __ENV.BATCH_JSONRPC_URL || "http://localhost:8083/jsonrpc";
const grpcAddress = __ENV.GRPC_ADDRESS || "localhost:50051";
const grpcProtoDir = __ENV.GRPC_PROTO_DIR || "../proto";
const grpcClient = new grpcModule.Client();
const grpcState = { connected: false };
grpcClient.load([grpcProtoDir], "tick.proto");

const requestDuration = new Trend("batch_protocol_request_duration", true);
const requests = new Counter("batch_protocol_requests");
const errors = new Counter("batch_protocol_errors");
const errorRate = new Rate("batch_protocol_error_rate");

const rateStages = quickTest
  ? [
      { target: 5, duration: "10s" },
      { target: 10, duration: "10s" },
      { target: 20, duration: "10s" },
    ]
  : [
      { target: 100, duration: "1m" },
      { target: 500, duration: "2m" },
      { target: 500, duration: "4m" },
    ];

function scenario(protocol, exec) {
  return {
    executor: "ramping-arrival-rate",
    startRate: 0,
    timeUnit: "1s",
    stages: rateStages,
    preAllocatedVUs: quickTest ? 50 : 1500,
    maxVUs: quickTest ? 100 : 1500,
    exec,
    tags: { protocol, batch_size: String(batchSize) },
  };
}

function thresholds() {
  const result = {
    batch_protocol_request_duration: ["p(95)<1000", "p(99)<2000"],
    batch_protocol_error_rate: ["rate<0.01"],
  };

  for (const protocol of protocols) {
    result[`batch_protocol_request_duration{protocol:${protocol}}`] = [
      "p(99)<120000",
    ];
    result[`batch_protocol_requests{protocol:${protocol}}`] = ["count>0"];
    result[`batch_protocol_error_rate{protocol:${protocol}}`] = ["rate<1"];
  }
  return result;
}

export const options = {
  tags: { testid: testId, workload: "batch", batch_size: String(batchSize) },
  summaryTrendStats: [
    "avg",
    "min",
    "med",
    "max",
    "p(50)",
    "p(90)",
    "p(95)",
    "p(99)",
    "count",
  ],
  scenarios: {
    rest: scenario("rest", "rest"),
    graphql: scenario("graphql", "graphql"),
    jsonrpc: scenario("jsonrpc", "jsonrpc"),
    grpc: scenario("grpc", "grpc"),
  },
  thresholds: thresholds(),
};

function record(protocol, duration, success) {
  const tags = { protocol, batch_size: String(batchSize) };
  requestDuration.add(Math.max(0, duration), tags);
  requests.add(1, tags);
  errorRate.add(!success, tags);
  if (!success) {
    errors.add(1, tags);
  }
}

function timedPost(url, body, protocol) {
  const start = Date.now();
  const response = http.post(url, JSON.stringify(body), {
    headers: jsonHeaders,
    tags: { protocol, batch_size: String(batchSize) },
  });
  return { response, duration: Date.now() - start };
}

function responseJson(response) {
  try {
    return response.json();
  } catch (_) {
    return null;
  }
}

export function rest() {
  const { response, duration } = timedPost(restUrl, ticks, "rest");
  const success = response.status === 200;
  record("rest", duration, success);
  check(success, {
    "REST batch response is valid": (result) => result === true,
  });
}

export function graphql() {
  const { response, duration } = timedPost(
    graphqlUrl,
    {
      query:
        "mutation IngestTickBatch($ticks: [TickInput!]!) { ingestTickBatch(ticks: $ticks) }",
      variables: { ticks },
    },
    "graphql",
  );
  const payload = responseJson(response);
  const success =
    response.status === 200 &&
    !payload?.errors &&
    payload?.data?.ingestTickBatch === true;
  record("graphql", duration, success);
  check(success, {
    "GraphQL batch response is valid": (result) => result === true,
  });
}

export function jsonrpc() {
  const id = __VU * 1000000 + __ITER;
  const { response, duration } = timedPost(
    jsonrpcUrl,
    {
      jsonrpc: "2.0",
      method: "ingest_tick_batch",
      params: ticks,
      id,
    },
    "jsonrpc",
  );
  const payload = responseJson(response);
  const success =
    response.status === 200 &&
    payload?.jsonrpc === "2.0" &&
    payload?.result === true &&
    payload?.id === id;
  record("jsonrpc", duration, success);
  check(success, {
    "JSON-RPC batch response is valid": (result) => result === true,
  });
}

export function grpc() {
  const protocol = "grpc";
  const start = Date.now();
  let success = false;

  try {
    if (!grpcState.connected) {
      grpcClient.connect(grpcAddress, { plaintext: true });
      grpcState.connected = true;
    }
    const response = grpcClient.invoke("tick.TickIngestion/IngestTickBatch", {
      ticks,
    });
    success = response && response.status === grpcModule.StatusOK;
  } catch (_) {
    success = false;
  }

  record(protocol, Date.now() - start, success);
  check(success, {
    "gRPC batch response is valid": (result) => result === true,
  });
}

export default function () {}

export function handleSummary(data) {
  const requestedPath = __ENV.RESULT_PATH || "k6_batch_results.json";
  const safePath = requestedPath
    .replaceAll("\\", "/")
    .replaceAll("..", "_")
    .replace(/^\/+/, "");
  return {
    [`/results/${safePath}`]: JSON.stringify(data, null, 2),
  };
}
