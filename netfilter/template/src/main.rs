use askama::Template;
mod subnet;

use subnet::Subnet;

#[derive(Template)]
#[template(path = "router.nft.txt")]
struct RouterTemplate<'a> {
    interface_lan: &'a str,
    interface_wan: &'a str,
    icmp_accept_lan: bool,
    icmp_accept_wan: bool,
    subnet_lan: Subnet,
}

fn main() {
    let router = RouterTemplate {
        interface_lan: "lan",
        interface_wan: "wan",
        icmp_accept_lan: true,
        icmp_accept_wan: false,
        subnet_lan: Subnet::new("192.168.10.1/24").unwrap(),
    };
    println!("{}", router.render().unwrap());
}
