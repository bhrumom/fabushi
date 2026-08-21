use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActorKind {
    Human,
    Assistant,
    Bot,
    Service,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Actor {
    pub id: String,
    pub kind: ActorKind,
    pub display_name: String,
    pub capabilities: Vec<String>,
}

impl Actor {
    pub fn human(id: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            kind: ActorKind::Human,
            display_name: name.into(),
            capabilities: Vec::new(),
        }
    }
}
