use axum::{Router, extract::Json, http::StatusCode, routing::post};
use jsonrpsee::proc_macros::rpc;
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::models::Tick;

#[rpc(server)]
pub trait TickRpc {
    #[method(name = "ingest_tick")]
    async fn ingest_tick(&self, tick: Tick) -> bool;

    #[method(name = "ingest_tick_batch")]
    async fn ingest_tick_batch(&self, ticks: Vec<Tick>) -> bool;
}

pub struct TickRpcImpl;

#[async_trait::async_trait]
impl TickRpcServer for TickRpcImpl {
    async fn ingest_tick(&self, _tick: Tick) -> bool {
        true
    }

    async fn ingest_tick_batch(&self, _ticks: Vec<Tick>) -> bool {
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
        if request.jsonrpc == "2.0" && request.method == "ingest_tick_batch" {
            return handle_batch_request(request).await;
        }
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

async fn handle_batch_request(request: JsonRpcRequest) -> (StatusCode, Json<Value>) {
    let Some(params) = request.params else {
        return (
            StatusCode::BAD_REQUEST,
            Json(json!({"jsonrpc": "2.0", "error": "missing params"})),
        );
    };

    let ticks = match serde_json::from_value::<Vec<Tick>>(params) {
        Ok(ticks) => ticks,
        Err(_) => {
            return (
                StatusCode::BAD_REQUEST,
                Json(json!({"jsonrpc": "2.0", "error": "invalid params"})),
            );
        }
    };

    let result = TickRpcServer::ingest_tick_batch(&TickRpcImpl, ticks).await;
    let response = JsonRpcResponse {
        jsonrpc: "2.0",
        result,
        id: request.id,
    };
    (StatusCode::OK, Json(json!(response)))
}

#[cfg(test)]
mod tests {
    use super::{JsonRpcRequest, jsonrpc_handler};
    use axum::{Json, http::StatusCode};
    use serde_json::json;

    #[tokio::test]
    async fn accepts_single_and_batch_requests() {
        let tick = json!({
            "symbol": "SHOP",
            "price": 115.42,
            "volume": 100,
            "timestamp": 1_700_000_000_u64
        });

        for (method, params) in [
            ("ingest_tick", tick.clone()),
            ("ingest_tick_batch", json!([tick])),
        ] {
            let request = JsonRpcRequest {
                jsonrpc: "2.0".to_owned(),
                method: method.to_owned(),
                params: Some(params),
                id: Some(json!(1)),
            };
            let (status, Json(body)) = jsonrpc_handler(Json(request)).await;

            assert_eq!(status, StatusCode::OK);
            assert_eq!(body["jsonrpc"], "2.0");
            assert_eq!(body["result"], true);
            assert_eq!(body["id"], 1);
        }
    }

    #[tokio::test]
    async fn rejects_an_unknown_method() {
        let request = JsonRpcRequest {
            jsonrpc: "2.0".to_owned(),
            method: "unknown".to_owned(),
            params: Some(json!({})),
            id: Some(json!(1)),
        };
        let (status, Json(body)) = jsonrpc_handler(Json(request)).await;

        assert_eq!(status, StatusCode::BAD_REQUEST);
        assert_eq!(body["error"], "invalid request");
    }
}
