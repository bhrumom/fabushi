//! Fabushi self-hosted messaging domain.
//!
//! This crate is intentionally independent from Telegram APIs and MTProto.
//! Telegram Desktop and Unigram are compatibility/UX references only; humans,
//! AI assistants, bots, services, payments, Mini Apps, realtime calls, media,
//! communities, stories, and durable sync share one Fabushi-owned protocol and
//! state machine.

pub mod actor;
pub mod community;
pub mod conversation;
pub mod engine;
pub mod media;
pub mod message;
pub mod miniapp;
pub mod payment;
pub mod payment_provider;
pub mod protocol;
pub mod realtime;
pub mod service;
pub mod store;
pub mod story;

pub use actor::*;
pub use community::*;
pub use conversation::*;
pub use engine::{Command, EngineError, Event, MessagingEngine, MessagingState};
pub use media::*;
pub use message::*;
pub use miniapp::*;
pub use payment::*;
pub use payment_provider::*;
pub use protocol::*;
pub use realtime::*;
pub use service::*;
pub use store::*;
pub use story::*;
