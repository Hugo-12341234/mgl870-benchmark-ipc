#!/usr/bin/env bash
set -euo pipefail

ghz \
  --insecure \
  --duration 2m \
  --proto proto/tick.proto \
  --call tick.TickIngestion.IngestTick \
  --data '{"symbol":"SHOP","price":115.42,"volume":100,"timestamp":1700000000}' \
  -O json \
  -o grpc_results.json \
  localhost:50051