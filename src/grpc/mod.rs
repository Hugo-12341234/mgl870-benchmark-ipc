pub mod tick {
    tonic::include_proto!("tick");
}

use tick::tick_ingestion_server::{TickIngestion, TickIngestionServer};
use tick::{Ack, TickList, TickMessage};
use tonic::{Request, Response, Status};

struct TickIngestionService;

#[tonic::async_trait]
impl TickIngestion for TickIngestionService {
    async fn ingest_tick(&self, _request: Request<TickMessage>) -> Result<Response<Ack>, Status> {
        Ok(Response::new(Ack {}))
    }

    async fn ingest_tick_batch(
        &self,
        _request: Request<TickList>,
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

#[cfg(test)]
mod tests {
    use super::{
        TickIngestion, TickIngestionService,
        tick::{TickList, TickMessage},
    };
    use tonic::Request;

    fn tick() -> TickMessage {
        TickMessage {
            symbol: "SHOP".to_owned(),
            price: 115.42,
            volume: 100,
            timestamp: 1_700_000_000,
        }
    }

    #[tokio::test]
    async fn accepts_a_single_tick() {
        let response = TickIngestionService.ingest_tick(Request::new(tick())).await;

        assert!(response.is_ok());
    }

    #[tokio::test]
    async fn accepts_a_tick_batch() {
        let response = TickIngestionService
            .ingest_tick_batch(Request::new(TickList {
                ticks: vec![tick()],
            }))
            .await;

        assert!(response.is_ok());
    }
}
