//! Fabushi self-hosted messaging domain.
//!
//! This crate is intentionally independent from Telegram APIs and MTProto.
//! Telegram Desktop and Unigram are compatibility/UX references only; humans,
//! AI assistants, bots, services, payments, and Mini Apps share one Fabushi
//! Actor/Conversation/Message model and one event-sourced state machine.

pub mod actor;
pub mod conversation;
pub mod engine;
pub mod message;
pub mod miniapp;
pub mod payment;
pub mod protocol;

pub use actor::*;
pub use conversation::*;
pub use engine::{Command, EngineError, Event, MessagingEngine, MessagingState};
pub use message::*;
pub use miniapp::*;
pub use payment::*;
pub use protocol::*;
