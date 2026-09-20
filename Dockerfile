FROM rust:latest AS builder

WORKDIR /app
RUN apt-get update \
    && apt-get install -y protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

COPY Cargo.toml Cargo.lock* ./
COPY src ./src
COPY proto ./proto
COPY build.rs ./build.rs
RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install --no-install-recommends -y ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/mgl870-benchmark-ipc /usr/local/bin/mgl870-benchmark-ipc

EXPOSE 8080 50051
ENTRYPOINT ["/usr/local/bin/mgl870-benchmark-ipc"]