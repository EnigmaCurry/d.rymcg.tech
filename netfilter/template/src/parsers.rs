use ipnetwork::IpNetwork;
use std::fmt;
use std::str::FromStr;

pub struct Subnet {
    network: IpNetwork,
}

impl Subnet {
    pub fn new(input: &str) -> Result<Self, String> {
        // Attempt to parse the input as an IpNetwork
        match IpNetwork::from_str(input) {
            Ok(network) => Ok(Self { network }),
            Err(_) => Err(format!("Invalid subnet format: {}", input)),
        }
    }
}

impl fmt::Display for Subnet {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.network)
    }
}
