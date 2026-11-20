use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize, PartialEq, Serialize)]
pub struct Tick {
    pub symbol: String,
    pub price: f64,
    pub volume: u32,
    pub timestamp: u64,
}

#[cfg(test)]
mod tests {
    use super::Tick;

    #[test]
    fn tick_round_trips_through_json() {
        let tick = Tick {
            symbol: "SHOP".to_owned(),
            price: 115.42,
            volume: 100,
            timestamp: 1_700_000_000,
        };

        let json = serde_json::to_string(&tick).expect("tick should serialize");
        let decoded: Tick = serde_json::from_str(&json).expect("tick should deserialize");

        assert_eq!(decoded, tick);
    }

    #[test]
    fn tick_rejects_an_incomplete_payload() {
        let incomplete = r#"{"symbol":"SHOP","price":115.42,"volume":100}"#;

        assert!(serde_json::from_str::<Tick>(incomplete).is_err());
    }
}
