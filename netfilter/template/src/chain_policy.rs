#[derive(Debug, Clone)]
#[allow(dead_code)]
pub enum ChainPolicy {
    Accept,
    Drop,
    Reject,
    Continue,
    Return,
    Queue,
    Log,
}

// Implementing Display for the enum to render in templates
impl std::fmt::Display for ChainPolicy {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ChainPolicy::Accept => write!(f, "accept"),
            ChainPolicy::Drop => write!(f, "drop"),
            ChainPolicy::Reject => write!(f, "reject"),
            ChainPolicy::Continue => write!(f, "continue"),
            ChainPolicy::Return => write!(f, "return"),
            ChainPolicy::Queue => write!(f, "queue"),
            ChainPolicy::Log => write!(f, "log"),
        }
    }
}
