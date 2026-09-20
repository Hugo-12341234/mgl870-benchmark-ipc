pub mod tick {
    tonic::include_proto!("tick");
}

use tick::tick_ingestion_server::{TickIngestion, TickIngestionServer};
use tick::{Ack, TickMessage};
use tonic::{Request, Response, Status};

struct TickIngestionService;

#[tonic::async_trait]
impl TickIngestion for TickIngestionService {
    async fn ingest_tick(
        &self,
        _request: Request<TickMessage>,
    ) -> Result<Response<Ack>, Status> {
        Ok(Response::new(Ack {}))
    }
}

pub async fn serve(address: &str) -> Result<(), tonic::transport::Error> {
    let address = address.parse().expect("invalid gRPC address");

    tonic::transport::Server::builder()
        .add_service(TickIngestionServer::new(TickIngestionService))
        .serve(address)
        .await
}