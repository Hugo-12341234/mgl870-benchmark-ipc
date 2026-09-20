use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, Serialize)]
pub struct Tick {
    pub symbol: String,
    pub price: f64,
    pub volume: u32,
    pub timestamp: u64,
}