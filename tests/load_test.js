import http from "k6/http";
import { check } from "k6";

const tick = {
  symbol: "SHOP",
  price: 115.42,
  volume: 100,
  timestamp: 1700000000,
};

const jsonHeaders = { "Content-Type": "application/json" };

export const options = {
  scenarios: {
    rest: {
      executor: "constant-vus",
      vus: 500,
      duration: "2m",
      exec: "rest",
    },
    graphql: {
      executor: "constant-vus",
      vus: 500,
      duration: "2m",
      exec: "graphql",
    },
    jsonrpc: {
      executor: "constant-vus",
      vus: 500,
      duration: "2m",
      exec: "jsonrpc",
    },
  },
  thresholds: {
    http_req_duration: ["p(95)<1000", "p(99)<2000"],
    http_req_failed: ["rate<0.01"],
  },
};

function post(url, body, protocol) {
  return http.post(url, JSON.stringify(body), {
    headers: jsonHeaders,
    tags: { protocol },
  });
}

export function rest() {
  const response = post("http://localhost:8081/api/ticks", tick, "rest");
  check(response, {
    "REST status is 200": (result) => result.status === 200,
  });
}

export function graphql() {
  const response = post(
    "http://localhost:8082/graphql",
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
    "http://localhost:8083/jsonrpc",
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

export default function () {}

export function handleSummary(data) {
  return { "k6_results.json": JSON.stringify(data, null, 2) };
}