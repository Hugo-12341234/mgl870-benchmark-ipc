import { sleep } from "k6";
import { Trend } from "k6/metrics";

// Both trends receive the exact same numeric value. The first one is marked as
// a time value, while the second one is intentionally unitless. Comparing the
// two Prometheus series reveals whether the remote-write output converts k6
// time values from milliseconds to Prometheus's base unit (seconds).
const timedDuration = new Trend("latency_unit_validation_duration", true);
const plainValue = new Trend("latency_unit_validation_plain", false);

export const options = {
  vus: 1,
  iterations: 8,
};

export default function () {
  timedDuration.add(1000, { probe: "exact_1000" });
  plainValue.add(1000, { probe: "exact_1000" });
  sleep(1);
}

export function handleSummary(data) {
  return {
    "/results/latency_unit_validation_summary.json": JSON.stringify(
      data,
      null,
      2,
    ),
  };
}
