import grpcModule from "k6/net/grpc";
import http from "k6/http";
import { check } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

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

const rateStages = [
  { target: 100, duration: "30s" },
  { target: 250, duration: "30s" },
  { target: 500, duration: "30s" },
  { target: 500, duration: "30s" },
];

function scenario(protocol, exec) {
  return {
    executor: "ramping-arrival-rate",
    startRate: 0,
    timeUnit: "1s",
    stages: rateStages,
    preAllocatedVUs: 500,
    maxVUs: 2000,
    exec,
    tags: { protocol },
  };
}

export const options = {
  scenarios: {
    rest: scenario("rest", "rest"),
    graphql: scenario("graphql", "graphql"),
    jsonrpc: scenario("jsonrpc", "jsonrpc"),
    grpc: scenario("grpc", "grpc"),
  },
  thresholds: {
    protocol_request_duration: ["p(95)<1000", "p(99)<2000"],
    protocol_error_rate: ["rate<0.01"],
  },
};

function record(protocol, start, success) {
  const tags = { protocol };
  const duration = Date.now() - start;
  requestDuration.add(duration, tags);
  requests.add(1, tags);
  errorRate.add(!success, tags);
  if (!success) {
    errors.add(1, tags);
  }
}

function post(url, body, protocol) {
  const start = Date.now();
  const response = http.post(url, JSON.stringify(body), {
    headers: jsonHeaders,
    tags: { protocol },
  });
  record(protocol, start, response.status === 200);
  return response;
}

export function rest() {
  const response = post(restUrl, tick, "rest");
  check(response, { "REST status is 200": (result) => result.status === 200 });
}

export function graphql() {
  const response = post(
    graphqlUrl,
    {
      query:
        "mutation IngestTick($tick: TickInput!) { ingestTick(tick: $tick) }",
      variables: { tick },
    },
    "graphql",
  );
  check(response, {
    "GraphQL status is 200": (result) => result.status === 200,
  });
}

export function jsonrpc() {
  const response = post(
    jsonrpcUrl,
    {
      jsonrpc: "2.0",
      method: "ingest_tick",
      params: tick,
      id: __VU * 1000000 + __ITER,
    },
    "jsonrpc",
  );
  check(response, {
    "JSON-RPC status is 200": (result) => result.status === 200,
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
    const response = grpcClient.invoke("tick.TickIngestion.IngestTick", tick);
    success = response && response.status === grpcModule.StatusOK;
  } catch (_) {
    success = false;
  }

  record(protocol, start, success);
  check(success, { "gRPC status is OK": (result) => result === true });
}

export default function () {}

export function handleSummary(data) {
  return { "k6_results.json": JSON.stringify(data, null, 2) };
}
