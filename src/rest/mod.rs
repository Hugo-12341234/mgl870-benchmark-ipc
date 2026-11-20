use axum::{Router, extract::Json, http::StatusCode, routing::post};

use crate::models::Tick;

pub fn router() -> Router {
    Router::new()
        .route("/api/ticks", post(accept_tick))
        .route("/api/ticks/batch", post(accept_tick_batch))
}

async fn accept_tick(Json(_tick): Json<Tick>) -> StatusCode {
    StatusCode::OK
}

async fn accept_tick_batch(Json(_ticks): Json<Vec<Tick>>) -> StatusCode {
    StatusCode::OK
}

#[cfg(test)]
mod tests {
    use super::router;
    use axum::{
        body::Body,
        http::{Request, StatusCode},
    };
    use tower::ServiceExt;

    async fn post_json(uri: &str, body: &'static str) -> StatusCode {
        router()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(uri)
                    .header("content-type", "application/json")
                    .body(Body::from(body))
                    .expect("request should be valid"),
            )
            .await
            .expect("router should answer")
            .status()
    }

    #[tokio::test]
    async fn accepts_single_and_batch_ticks() {
        let tick = r#"{"symbol":"SHOP","price":115.42,"volume":100,"timestamp":1700000000}"#;
        let batch = r#"[{"symbol":"SHOP","price":115.42,"volume":100,"timestamp":1700000000}]"#;

        assert_eq!(post_json("/api/ticks", tick).await, StatusCode::OK);
        assert_eq!(post_json("/api/ticks/batch", batch).await, StatusCode::OK);
    }

    #[tokio::test]
    async fn rejects_an_invalid_tick() {
        let incomplete = r#"{"symbol":"SHOP","price":115.42}"#;

        assert!(!post_json("/api/ticks", incomplete).await.is_success());
    }
}
