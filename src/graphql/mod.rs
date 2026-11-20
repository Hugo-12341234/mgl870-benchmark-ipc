use async_graphql::{EmptySubscription, InputObject, Object, Schema};
use async_graphql_axum::{GraphQLRequest, GraphQLResponse};
use axum::{Router, extract::State, routing::post};

#[derive(InputObject)]
struct TickInput {
    symbol: String,
    price: f64,
    volume: u32,
    timestamp: u64,
}

struct Query;
struct Mutation;

#[Object]
impl Query {
    async fn health(&self) -> bool {
        true
    }
}

#[Object]
impl Mutation {
    async fn ingest_tick(&self, tick: TickInput) -> bool {
        let _ = tick;
        true
    }

    async fn ingest_tick_batch(&self, ticks: Vec<TickInput>) -> bool {
        let _ = ticks;
        true
    }
}

type TickSchema = Schema<Query, Mutation, EmptySubscription>;

fn schema() -> TickSchema {
    Schema::build(Query, Mutation, EmptySubscription).finish()
}

pub fn router() -> Router {
    Router::new()
        .route("/graphql", post(graphql_handler))
        .with_state(schema())
}

async fn graphql_handler(
    State(schema): State<TickSchema>,
    request: GraphQLRequest,
) -> GraphQLResponse {
    schema.execute(request.into_inner()).await.into()
}

#[cfg(test)]
mod tests {
    use super::schema;
    use async_graphql::Request;
    use serde_json::json;

    #[tokio::test]
    async fn accepts_single_and_batch_mutations() {
        let single = schema()
            .execute(Request::new(
                r#"mutation { ingestTick(tick: { symbol: "SHOP", price: 115.42, volume: 100, timestamp: 1700000000 }) }"#,
            ))
            .await;
        assert!(single.errors.is_empty());
        assert_eq!(
            single.data.into_json().expect("data should be JSON"),
            json!({"ingestTick": true})
        );

        let batch = schema()
            .execute(Request::new(
                r#"mutation { ingestTickBatch(ticks: [{ symbol: "SHOP", price: 115.42, volume: 100, timestamp: 1700000000 }]) }"#,
            ))
            .await;
        assert!(batch.errors.is_empty());
        assert_eq!(
            batch.data.into_json().expect("data should be JSON"),
            json!({"ingestTickBatch": true})
        );
    }

    #[tokio::test]
    async fn rejects_a_mutation_with_a_missing_required_field() {
        let response = schema()
            .execute(Request::new(
                r#"mutation { ingestTick(tick: { symbol: "SHOP", price: 115.42, volume: 100 }) }"#,
            ))
            .await;

        assert!(!response.errors.is_empty());
    }
}
