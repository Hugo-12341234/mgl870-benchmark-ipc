use axum::{extract::Json, http::StatusCode, routing::post, Router};

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