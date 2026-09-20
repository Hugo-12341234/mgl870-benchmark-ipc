mod models;
mod graphql;
mod grpc;
mod jsonrpc;
mod rest;

#[tokio::main]
async fn main() {
    tokio::spawn(async {
        grpc::serve("0.0.0.0:50051")
            .await
            .expect("gRPC server failed");
    });

    let app = rest::router()
        .merge(graphql::router())
        .merge(jsonrpc::router());
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080")
        .await
        .expect("failed to bind server listener");

    axum::serve(listener, app)
        .await
        .expect("server failed");
}
