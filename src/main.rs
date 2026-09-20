mod models;
mod rest;

#[tokio::main]
async fn main() {
    let app = rest::router();
    let listener = tokio::net::TcpListener::bind("0.0.0.0:8080")
        .await
        .expect("failed to bind server listener");

    axum::serve(listener, app)
        .await
        .expect("server failed");
}
