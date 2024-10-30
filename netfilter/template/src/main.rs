use askama::Template;

mod chain_policy;
use chain_policy::ChainPolicy;

#[template(path = "router.nft.txt")]
#[derive(Template)]
struct RouterTemplate {
    chain_policy_input: ChainPolicy,
    chain_policy_output: ChainPolicy,
    chain_policy_forward: ChainPolicy,
    chain_policy_prerouting: ChainPolicy,
    chain_policy_postrouting: ChainPolicy,
}

fn main() {
    let router = RouterTemplate {
        chain_policy_input: ChainPolicy::Drop,
        chain_policy_output: ChainPolicy::Accept,
        chain_policy_forward: ChainPolicy::Drop,
        chain_policy_postrouting: ChainPolicy::Accept,
        chain_policy_prerouting: ChainPolicy::Accept,
    }; // instantiate your struct
    println!("{}", router.render().unwrap()); // then render it.
}
