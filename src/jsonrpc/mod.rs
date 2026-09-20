use axum::{extract::Json, http::StatusCode, routing::post, Router};
use jsonrpsee::proc_macros::rpc;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::models::Tick;

#[rpc(server)]
pub trait TickRpc {
    #[method(name = "ingest_tick")]
    async fn ingest_tick(&self, tick: Tick) -> bool;
}

pub struct TickRpcImpl;

#[async_trait::async_trait]
impl TickRpcServer for TickRpcImpl {
    async fn ingest_tick(&self, _tick: Tick) -> bool {
        true
    }
}

#[derive(Deserialize)]
struct JsonRpcRequest {
    jsonrpc: String,
    method: String,
    params: Option<Value>,
    id: Option<Value>,
}

#[derive(Serialize)]
struct JsonRpcResponse {
    jsonrpc: &'static str,
    result: bool,
    id: Option<Value>,
}

pub fn router() -> Router {
    Router::new().route("/jsonrpc", post(jsonrpc_handler))
}

async fn jsonrpc_handler(Json(request): Json<JsonRpcRequest>) -> (StatusCode, Json<Value>) {
    if request.jsonrpc != "2.0" || request.method != "ingest_tick" {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({"jsonrpc": "2.0", "error": "invalid request"})),
        );
    }

    let Some(params) = request.params else {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({"jsonrpc": "2.0", "error": "missing params"})),
        );
    };

    let tick = match serde_json::from_value::<Tick>(params) {
        Ok(tick) => tick,
        Err(_) => {
            return (
                StatusCode::BAD_REQUEST,
                Json(json!({"jsonrpc": "2.0", "error": "invalid params"})),
            );
        }
    };

    let result = TickRpcServer::ingest_tick(&TickRpcImpl, tick).await;

    let response = JsonRpcResponse {
        jsonrpc: "2.0",
        result,
        id: request.id,
    };
    (StatusCode::OK, Json(json!(response)))
}