use crate::actor::ActorId;
use crate::engine::{Command, EngineError, Event, MessagingEngine};
use crate::message::MessageId;
use crate::protocol::{
    ClientCommand, ClientEnvelope, ServerEnvelope, ServerEvent, FABUSHI_MESSAGING_PROTOCOL_VERSION,
};
use crate::store::{MessagingSnapshot, MessagingStateStore, StoreError};
use thiserror::Error;

#[derive(Debug, Error)]
pub enum MessagingServiceError {
    #[error("unsupported messaging protocol version {actual}; expected {expected}")]
    ProtocolVersion { expected: u16, actual: u16 },
    #[error(transparent)]
    Engine(#[from] EngineError),
    #[error(transparent)]
    Store(#[from] StoreError),
}

pub struct MessagingService<S: MessagingStateStore> {
    engine: MessagingEngine,
    store: S,
    cursor: u64,
}

impl<S: MessagingStateStore> MessagingService<S> {
    pub fn load(store: S) -> Result<Self, MessagingServiceError> {
        let snapshot = store.load()?;
        let (engine, cursor) = match snapshot {
            Some(snapshot) => (MessagingEngine::from_state(snapshot.state), snapshot.cursor),
            None => (MessagingEngine::new(), 0),
        };
        Ok(Self {
            engine,
            store,
            cursor,
        })
    }

    pub fn engine(&self) -> &MessagingEngine {
        &self.engine
    }

    pub fn cursor(&self) -> u64 {
        self.cursor
    }

    pub fn into_store(self) -> S {
        self.store
    }

    pub fn handle(
        &mut self,
        envelope: ClientEnvelope,
        server_time_ms: i64,
    ) -> Result<Vec<ServerEnvelope>, MessagingServiceError> {
        if envelope.protocol_version != FABUSHI_MESSAGING_PROTOCOL_VERSION {
            return Err(MessagingServiceError::ProtocolVersion {
                expected: FABUSHI_MESSAGING_PROTOCOL_VERSION,
                actual: envelope.protocol_version,
            });
        }

        let actor_id = envelope.context.actor_id;
        let command = envelope.command;
        if let ClientCommand::Sync { limit, .. } = &command {
            return Ok(vec![self.sync_envelope(*limit, server_time_ms)]);
        }

        let commands = self.project_command(&actor_id, command, server_time_ms);
        let mut events = Vec::new();
        for command in commands {
            events.extend(self.engine.execute(command)?);
        }
        if events.is_empty() {
            return Ok(Vec::new());
        }

        self.cursor = self.cursor.saturating_add(events.len() as u64);
        self.persist(server_time_ms)?;
        Ok(events
            .into_iter()
            .filter_map(|event| self.project_event(event, server_time_ms))
            .collect())
    }

    fn sync_envelope(&self, limit: u32, server_time_ms: i64) -> ServerEnvelope {
        let state = self.engine.state();
        let max_items = usize::try_from(limit.max(1)).unwrap_or(usize::MAX);
        ServerEnvelope {
            protocol_version: FABUSHI_MESSAGING_PROTOCOL_VERSION,
            cursor: Some(self.cursor.to_string()),
            server_time_ms,
            event: ServerEvent::SyncBatch {
                actors: state.actors.values().take(max_items).cloned().collect(),
                conversations: state
                    .conversations
                    .values()
                    .take(max_items)
                    .cloned()
                    .collect(),
                messages: state
                    .messages
                    .values()
                    .flat_map(|messages| messages.values())
                    .take(max_items)
                    .cloned()
                    .collect(),
                folders: state.folders.values().take(max_items).cloned().collect(),
                invoices: state.invoices.values().take(max_items).cloned().collect(),
                orders: state.orders.values().take(max_items).cloned().collect(),
                mini_apps: state.mini_apps.values().take(max_items).cloned().collect(),
                next_cursor: Some(self.cursor.to_string()),
            },
        }
    }

    fn project_command(
        &self,
        actor_id: &ActorId,
        command: ClientCommand,
        now_ms: i64,
    ) -> Vec<Command> {
        match command {
            ClientCommand::Sync { .. } => Vec::new(),
            ClientCommand::UpsertProfile { actor } => vec![Command::UpsertActor { actor }],
            ClientCommand::SetPresence { presence } => vec![Command::SetPresence {
                actor_id: actor_id.clone(),
                presence,
            }],
            ClientCommand::CreateConversation { conversation }
            | ClientCommand::UpdateConversation { conversation } => {
                vec![Command::UpsertConversation { conversation }]
            }
            ClientCommand::ArchiveConversation {
                conversation_id,
                archived,
            } => vec![Command::ArchiveConversation {
                conversation_id,
                archived,
            }],
            ClientCommand::PinConversation {
                conversation_id,
                pinned,
            } => vec![Command::PinConversation {
                conversation_id,
                pinned,
            }],
            ClientCommand::SetConversationNotifications {
                conversation_id,
                settings,
            } => vec![Command::SetConversationNotifications {
                conversation_id,
                settings,
            }],
            ClientCommand::UpsertFolder { folder } => vec![Command::UpsertFolder { folder }],
            ClientCommand::DeleteFolder { folder_id } => vec![Command::DeleteFolder { folder_id }],
            ClientCommand::SendMessage {
                conversation_id,
                client_message_id,
                content,
                reply_to_message_id,
                thread_root_message_id,
                scheduled_at_ms,
                silent,
                protected_content,
            } => vec![Command::QueueMessage {
                conversation_id,
                local_message_id: MessageId::new(format!("local:{}", client_message_id.0)),
                client_message_id,
                sender_id: actor_id.clone(),
                content,
                reply_to_message_id,
                thread_root_message_id,
                created_at_ms: now_ms,
                scheduled_at_ms,
                silent,
                protected_content,
            }],
            ClientCommand::EditMessage {
                conversation_id,
                message_id,
                content,
            } => vec![Command::EditMessage {
                conversation_id,
                message_id,
                content,
                edited_at_ms: now_ms,
            }],
            ClientCommand::DeleteMessages {
                conversation_id,
                message_ids,
                ..
            } => vec![Command::DeleteMessages {
                conversation_id,
                message_ids,
            }],
            ClientCommand::MarkRead {
                conversation_id,
                message_id,
            } => vec![Command::MarkRead {
                conversation_id,
                actor_id: actor_id.clone(),
                message_id,
            }],
            ClientCommand::SetReaction {
                conversation_id,
                message_id,
                reaction,
            } => vec![Command::SetReaction {
                conversation_id,
                message_id,
                reaction,
            }],
            ClientCommand::PinMessage {
                conversation_id,
                message_id,
                pinned,
            } => vec![Command::PinMessage {
                conversation_id,
                message_id,
                pinned,
            }],
            ClientCommand::StartTyping { .. } | ClientCommand::StopTyping { .. } => Vec::new(),
            ClientCommand::CreateInvoice { invoice } => vec![Command::CreateInvoice { invoice }],
            ClientCommand::CheckoutInvoice { order, .. } => vec![Command::UpsertOrder { order }],
            ClientCommand::InstallMiniApp { manifest } => {
                vec![Command::InstallMiniApp { manifest }]
            }
            ClientCommand::GrantMiniApp { grant } => vec![Command::GrantMiniApp { grant }],
            ClientCommand::OpenMiniApp { session } => vec![Command::OpenMiniApp { session }],
            ClientCommand::MiniAppCall {
                session_id,
                request_id,
                request,
            } => vec![Command::MiniAppCall {
                session_id,
                request_id,
                request,
            }],
        }
    }

    fn project_event(&self, event: Event, server_time_ms: i64) -> Option<ServerEnvelope> {
        let server_event = match event {
            Event::ActorUpserted { actor } => ServerEvent::ActorChanged { actor },
            Event::PresenceUpdated { actor_id, presence } => {
                ServerEvent::PresenceChanged { actor_id, presence }
            }
            Event::ConversationUpserted { conversation } => {
                ServerEvent::ConversationChanged { conversation }
            }
            Event::ConversationArchived {
                conversation_id, ..
            }
            | Event::ConversationPinned {
                conversation_id, ..
            }
            | Event::ConversationNotificationsUpdated {
                conversation_id, ..
            } => self
                .engine
                .state()
                .conversations
                .get(&conversation_id)
                .cloned()
                .map(|conversation| ServerEvent::ConversationChanged { conversation })?,
            Event::FolderUpserted { folder } => ServerEvent::FolderChanged { folder },
            Event::FolderDeleted { folder_id } => ServerEvent::FolderDeleted { folder_id },
            Event::MessageQueued { message } => ServerEvent::MessageAdded { message },
            Event::MessageAcknowledged {
                conversation_id,
                server_message_id,
                ..
            }
            | Event::DeliveryStateUpdated {
                conversation_id,
                message_id: server_message_id,
                ..
            }
            | Event::MessageEdited {
                conversation_id,
                message_id: server_message_id,
                ..
            }
            | Event::ReactionUpdated {
                conversation_id,
                message_id: server_message_id,
                ..
            }
            | Event::MessagePinned {
                conversation_id,
                message_id: server_message_id,
                ..
            } => self
                .engine
                .state()
                .messages
                .get(&conversation_id)
                .and_then(|messages| messages.get(&server_message_id))
                .cloned()
                .map(|message| ServerEvent::MessageChanged { message })?,
            Event::MessagesDeleted {
                conversation_id,
                message_ids,
            } => ServerEvent::MessagesDeleted {
                conversation_id,
                message_ids,
            },
            Event::ConversationRead {
                conversation_id,
                actor_id,
                message_id,
            } => ServerEvent::ReadChanged {
                conversation_id,
                actor_id,
                message_id,
            },
            Event::InvoiceCreated { invoice } => ServerEvent::InvoiceChanged { invoice },
            Event::OrderUpserted { order } => ServerEvent::OrderChanged { order },
            Event::MiniAppInstalled { manifest } => ServerEvent::MiniAppChanged { manifest },
            Event::MiniAppGrantUpdated { .. } => return None,
            Event::MiniAppOpened { session } => ServerEvent::MiniAppOpened { session },
            Event::MiniAppResponded {
                session_id,
                request_id,
                response,
            } => ServerEvent::MiniAppResult {
                session_id,
                request_id,
                response,
            },
        };
        Some(ServerEnvelope {
            protocol_version: FABUSHI_MESSAGING_PROTOCOL_VERSION,
            cursor: Some(self.cursor.to_string()),
            server_time_ms,
            event: server_event,
        })
    }

    fn persist(&mut self, now_ms: i64) -> Result<(), MessagingServiceError> {
        let snapshot = MessagingSnapshot::new(self.engine.state().clone(), self.cursor, now_ms);
        self.store.save(&snapshot)?;
        Ok(())
    }
}
