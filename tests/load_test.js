import http from "k6/http";
import { check } from "k6";

const baseUrl = __ENV.BASE_URL || "http://localhost:8080";
const protocol = (__ENV.PROTOCOL || "rest").toLowerCase();
const tick = {
  symbol: "SHOP",
  price: 115.42,
  volume: 100,
  timestamp: 1700000000,
};

export const options = {
  stages: [
    { duration: "30s", target: 100 },
    { duration: "30s", target: 500 },
    { duration: "1m", target: 500 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<1000", "p(99)<2000"],
    http_req_failed: ["rate<0.01"],
  },
};

function post(url, body) {
  return http.post(url, body, {
    headers: { "Content-Type": "application/json" },
  });
}

export default function () {
  let response;

  switch (protocol) {
    case "rest":
      response = post(`${baseUrl}/api/ticks`, JSON.stringify(tick));
      break;
    case "graphql":
      response = post(
        `${baseUrl}/graphql`,
        JSON.stringify({
          query:
            "mutation IngestTick($tick: TickInput!) { ingest_tick(tick: $tick) }",
          variables: { tick },
        }),
      );
      break;
    case "jsonrpc":
      response = post(
        `${baseUrl}/jsonrpc`,
        JSON.stringify({
          jsonrpc: "2.0",
          method: "ingest_tick",
          params: tick,
          id: __VU * 1000000 + __ITER,
        }),
      );
      break;
    default:
      throw new Error(`Unsupported PROTOCOL: ${protocol}`);
  }

  check(response, {
    "status is 200": (result) => result.status === 200,
  });
}