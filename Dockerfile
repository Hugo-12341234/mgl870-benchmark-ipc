FROM rust:latest@sha256:223cc32ddca8f3ee90c436dbc94b6b5f052ea7f9653c5201e9612f08ad7d21b8 AS builder

WORKDIR /app
RUN apt-get update \
    && apt-get install -y protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock* ./
COPY src ./src
COPY proto ./proto
COPY build.rs ./build.rs
RUN cargo build --release

FROM debian:bookworm-slim@sha256:734a72b3d6142a71993b4bc580ca01d8ca687f77a2c422d96a961d3376b179bc

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/mgl870-benchmark-ipc /usr/local/bin/mgl870-benchmark-ipc

EXPOSE 8080 50051
ENTRYPOINT ["/usr/local/bin/mgl870-benchmark-ipc"]
