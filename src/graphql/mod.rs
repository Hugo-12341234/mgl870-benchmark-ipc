use async_graphql::{EmptySubscription, InputObject, Object, Schema};
use async_graphql_axum::{GraphQLRequest, GraphQLResponse};
use axum::{extract::State, routing::post, Router};

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
}

type TickSchema = Schema<Query, Mutation, EmptySubscription>;

pub fn router() -> Router {
    let schema = Schema::build(Query, Mutation, EmptySubscription).finish();
    Router::new()
        .route("/graphql", post(graphql_handler))
        .with_state(schema)
}

async fn graphql_handler(
    State(schema): State<TickSchema>,
    request: GraphQLRequest,
) -> GraphQLResponse {
    schema.execute(request.into_inner()).await.into()
}