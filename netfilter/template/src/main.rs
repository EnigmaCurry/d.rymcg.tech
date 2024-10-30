use askama::Template;
use std::env;
mod subnet;

use subnet::Subnet;

#[derive(Template)]
#[template(path = "router.nft.txt")]
struct RouterTemplate {
    interface_lan: String,
    interface_wan: String,
    icmp_accept_lan: bool,
    icmp_accept_wan: bool,
    subnet_lan: Subnet,
}

impl RouterTemplate {
    fn from_env() -> Self {
        let interface_lan = env::var("INTERFACE_LAN").unwrap_or_else(|_| "lan".to_string());
        let interface_wan = env::var("INTERFACE_WAN").unwrap_or_else(|_| "wan".to_string());
        let subnet_lan = env::var("SUBNET_LAN")
            .map(|v| Subnet::new(&v).unwrap())
            .unwrap_or_else(|_| Subnet::new("192.168.10.1/24").unwrap());
        let icmp_accept_lan = env::var("ICMP_ACCEPT_LAN")
            .map(|v| v == "true")
            .unwrap_or(true);
        let icmp_accept_wan = env::var("ICMP_ACCEPT_WAN")
            .map(|v| v == "true")
            .unwrap_or(false);

        RouterTemplate {
            interface_lan,
            interface_wan,
            subnet_lan,
            icmp_accept_lan,
            icmp_accept_wan,
        }
    }
}

fn main() {
    let router = RouterTemplate::from_env();
    println!("{}", router.render().unwrap());
}
