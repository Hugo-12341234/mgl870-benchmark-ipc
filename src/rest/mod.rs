use axum::{extract::Json, http::StatusCode, routing::post, Router};

use crate::models::Tick;

pub fn router() -> Router {
    Router::new().route("/api/ticks", post(accept_tick))
}

async fn accept_tick(Json(_tick): Json<Tick>) -> StatusCode {
    StatusCode::OK
}