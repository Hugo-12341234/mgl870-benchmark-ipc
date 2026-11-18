import grpcModule from "k6/net/grpc";
import http from "k6/http";
import { check } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

const protocols = ["rest", "graphql", "jsonrpc", "grpc"];
const quickTest = __ENV.QUICK_TEST === "true";
const testId = __ENV.TEST_ID || "manual-individual";

const tick = {
  symbol: "SHOP",
  price: 115.42,
  volume: 100,
  timestamp: 1700000000,
};

const jsonHeaders = { "Content-Type": "application/json" };
const restUrl = __ENV.REST_URL || "http://localhost:8081/api/ticks";
const graphqlUrl = __ENV.GRAPHQL_URL || "http://localhost:8082/graphql";
const jsonrpcUrl = __ENV.JSONRPC_URL || "http://localhost:8083/jsonrpc";
const grpcAddress = __ENV.GRPC_ADDRESS || "localhost:50051";
const grpcProtoDir = __ENV.GRPC_PROTO_DIR || "../proto";
const grpcClient = new grpcModule.Client();
const grpcState = { connected: false };
grpcClient.load([grpcProtoDir], "tick.proto");

const requestDuration = new Trend("protocol_request_duration", true);
const requests = new Counter("protocol_requests");
const errors = new Counter("protocol_errors");
const errorRate = new Rate("protocol_error_rate");

const rateStages = quickTest
  ? [
      { target: 20, duration: "10s" },
      { target: 50, duration: "10s" },
      { target: 100, duration: "10s" },
    ]
  : [
      { target: 2000, duration: "3m" },
      { target: 4000, duration: "3m" },
      { target: 6000, duration: "4m" },
    ];

function scenario(protocol, exec) {
  return {
    executor: "ramping-arrival-rate",
    startRate: 0,
    timeUnit: "1s",
    stages: rateStages,
    preAllocatedVUs: quickTest ? 100 : 4000,
    maxVUs: quickTest ? 200 : 4000,
    exec,
    tags: { protocol },
  };
}

function thresholds() {
  const result = {
    protocol_request_duration: ["p(95)<1000", "p(99)<2000"],
    protocol_error_rate: ["rate<0.01"],
  };

  // Tagged thresholds force k6 to retain per-protocol submetrics in the JSON
  // summary. Their broad limits are not SLOs; the global thresholds above are
  // the explicit saturation objectives.
  for (const protocol of protocols) {
    result[`protocol_request_duration{protocol:${protocol}}`] = [
      "p(99)<120000",
    ];
    result[`protocol_requests{protocol:${protocol}}`] = ["count>0"];
    result[`protocol_error_rate{protocol:${protocol}}`] = ["rate<1"];
  }
  return result;
}

export const options = {
  tags: { testid: testId, workload: "individual" },
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
  const tags = { protocol };
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
    tags: { protocol },
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
  const { response, duration } = timedPost(restUrl, tick, "rest");
  const success = response.status === 200;
  record("rest", duration, success);
  check(success, { "REST response is valid": (result) => result === true });
}

export function graphql() {
  const { response, duration } = timedPost(
    graphqlUrl,
    {
      query:
        "mutation IngestTick($tick: TickInput!) { ingestTick(tick: $tick) }",
      variables: { tick },
    },
    "graphql",
  );
  const payload = responseJson(response);
  const success =
    response.status === 200 &&
    !payload?.errors &&
    payload?.data?.ingestTick === true;
  record("graphql", duration, success);
  check(success, {
    "GraphQL response is valid": (result) => result === true,
  });
}

export function jsonrpc() {
  const id = __VU * 1000000 + __ITER;
  const { response, duration } = timedPost(
    jsonrpcUrl,
    {
      jsonrpc: "2.0",
      method: "ingest_tick",
      params: tick,
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
    "JSON-RPC response is valid": (result) => result === true,
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
    const response = grpcClient.invoke("tick.TickIngestion/IngestTick", tick);
    success = response && response.status === grpcModule.StatusOK;
  } catch (_) {
    success = false;
  }

  record(protocol, Date.now() - start, success);
  check(success, { "gRPC response is valid": (result) => result === true });
}

export default function () {}

export function handleSummary(data) {
  const requestedPath = __ENV.RESULT_PATH || "k6_results.json";
  const safePath = requestedPath
    .replaceAll("\\", "/")
    .replaceAll("..", "_")
    .replace(/^\/+/, "");
  return {
    [`/results/${safePath}`]: JSON.stringify(data, null, 2),
  };
}
