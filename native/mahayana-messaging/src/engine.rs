use crate::actor::{Actor, ActorId, Presence};
use crate::conversation::{Conversation, ConversationFolder, ConversationId, NotificationSettings};
use crate::message::{
    ClientMessageId, DeliveryState, Message, MessageContent, MessageId, ReactionSummary,
};
use crate::miniapp::{
    MiniAppGrant, MiniAppManifest, MiniAppPermission, MiniAppRequest, MiniAppResponse,
    MiniAppSession,
};
use crate::payment::{Invoice, PaymentOrder, PaymentStatus};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeMap, BTreeSet};
use thiserror::Error;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "type"
)]
pub enum Command {
    UpsertActor {
        actor: Actor,
    },
    SetPresence {
        actor_id: ActorId,
        presence: Presence,
    },
    UpsertConversation {
        conversation: Conversation,
    },
    ArchiveConversation {
        conversation_id: ConversationId,
        archived: bool,
    },
    PinConversation {
        conversation_id: ConversationId,
        pinned: bool,
    },
    SetConversationNotifications {
        conversation_id: ConversationId,
        settings: NotificationSettings,
    },
    UpsertFolder {
        folder: ConversationFolder,
    },
    DeleteFolder {
        folder_id: String,
    },
    QueueMessage {
        conversation_id: ConversationId,
        local_message_id: MessageId,
        client_message_id: ClientMessageId,
        sender_id: ActorId,
        content: MessageContent,
        reply_to_message_id: Option<MessageId>,
        thread_root_message_id: Option<MessageId>,
        created_at_ms: i64,
        scheduled_at_ms: Option<i64>,
        silent: bool,
        protected_content: bool,
    },
    ForwardMessage {
        source_conversation_id: ConversationId,
        message_id: MessageId,
        destination_conversation_id: ConversationId,
        local_message_id: MessageId,
        client_message_id: ClientMessageId,
        sender_id: ActorId,
        created_at_ms: i64,
    },
    AcknowledgeMessage {
        conversation_id: ConversationId,
        local_message_id: MessageId,
        server_message_id: MessageId,
        accepted_at_ms: i64,
    },
    SetDeliveryState {
        conversation_id: ConversationId,
        message_id: MessageId,
        state: DeliveryState,
    },
    EditMessage {
        conversation_id: ConversationId,
        message_id: MessageId,
        content: MessageContent,
        edited_at_ms: i64,
    },
    DeleteMessages {
        conversation_id: ConversationId,
        message_ids: Vec<MessageId>,
    },
    MarkRead {
        conversation_id: ConversationId,
        actor_id: ActorId,
        message_id: MessageId,
    },
    SetReaction {
        conversation_id: ConversationId,
        message_id: MessageId,
        reaction: ReactionSummary,
    },
    PinMessage {
        conversation_id: ConversationId,
        message_id: MessageId,
        pinned: bool,
    },
    CreateInvoice {
        invoice: Invoice,
    },
    UpsertOrder {
        order: PaymentOrder,
    },
    InstallMiniApp {
        manifest: MiniAppManifest,
    },
    GrantMiniApp {
        grant: MiniAppGrant,
    },
    OpenMiniApp {
        session: MiniAppSession,
    },
    MiniAppCall {
        session_id: String,
        request_id: String,
        request: MiniAppRequest,
    },
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(
    rename_all = "camelCase",
    rename_all_fields = "camelCase",
    tag = "type"
)]
pub enum Event {
    ActorUpserted {
        actor: Actor,
    },
    PresenceUpdated {
        actor_id: ActorId,
        presence: Presence,
    },
    ConversationUpserted {
        conversation: Conversation,
    },
    ConversationArchived {
        conversation_id: ConversationId,
        archived: bool,
    },
    ConversationPinned {
        conversation_id: ConversationId,
        pinned: bool,
    },
    ConversationNotificationsUpdated {
        conversation_id: ConversationId,
        settings: NotificationSettings,
    },
    FolderUpserted {
        folder: ConversationFolder,
    },
    FolderDeleted {
        folder_id: String,
    },
    MessageQueued {
        message: Message,
    },
    MessageAcknowledged {
        conversation_id: ConversationId,
        local_message_id: MessageId,
        server_message_id: MessageId,
        accepted_at_ms: i64,
    },
    DeliveryStateUpdated {
        conversation_id: ConversationId,
        message_id: MessageId,
        state: DeliveryState,
    },
    MessageEdited {
        conversation_id: ConversationId,
        message_id: MessageId,
        content: MessageContent,
        edited_at_ms: i64,
    },
    MessagesDeleted {
        conversation_id: ConversationId,
        message_ids: Vec<MessageId>,
    },
    ConversationRead {
        conversation_id: ConversationId,
        actor_id: ActorId,
        message_id: MessageId,
    },
    ReactionUpdated {
        conversation_id: ConversationId,
        message_id: MessageId,
        reaction: ReactionSummary,
    },
    MessagePinned {
        conversation_id: ConversationId,
        message_id: MessageId,
        pinned: bool,
    },
    InvoiceCreated {
        invoice: Invoice,
    },
    OrderUpserted {
        order: PaymentOrder,
    },
    MiniAppInstalled {
        manifest: MiniAppManifest,
    },
    MiniAppGrantUpdated {
        grant: MiniAppGrant,
    },
    MiniAppOpened {
        session: MiniAppSession,
    },
    MiniAppResponded {
        session_id: String,
        request_id: String,
        response: MiniAppResponse,
    },
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct MessagingState {
    pub actors: BTreeMap<ActorId, Actor>,
    pub conversations: BTreeMap<ConversationId, Conversation>,
    pub folders: BTreeMap<String, ConversationFolder>,
    pub messages: BTreeMap<ConversationId, BTreeMap<MessageId, Message>>,
    pub invoices: BTreeMap<String, Invoice>,
    pub orders: BTreeMap<String, PaymentOrder>,
    pub mini_apps: BTreeMap<String, MiniAppManifest>,
    pub mini_app_grants: BTreeMap<(String, ActorId), MiniAppGrant>,
    pub mini_app_sessions: BTreeMap<String, MiniAppSession>,
}

#[derive(Debug, Error, Clone, PartialEq, Eq)]
pub enum EngineError {
    #[error("actor identifier is invalid")]
    InvalidActor,
    #[error("actor {0:?} does not exist")]
    ActorNotFound(ActorId),
    #[error("conversation identifier is invalid")]
    InvalidConversation,
    #[error("conversation {0:?} does not exist")]
    ConversationNotFound(ConversationId),
    #[error("message {message_id:?} does not exist in conversation {conversation_id:?}")]
    MessageNotFound {
        conversation_id: ConversationId,
        message_id: MessageId,
    },
    #[error("message {message_id:?} already exists in conversation {conversation_id:?}")]
    DuplicateMessage {
        conversation_id: ConversationId,
        message_id: MessageId,
    },
    #[error("client message identifier is invalid")]
    InvalidClientMessageId,
    #[error("message id list must not be empty")]
    EmptyMessageList,
    #[error("message is protected from forwarding")]
    ProtectedContent,
    #[error("invoice is invalid")]
    InvalidInvoice,
    #[error("invoice {0} does not exist")]
    InvoiceNotFound(String),
    #[error("payment order {0} does not exist")]
    OrderNotFound(String),
    #[error("Mini App {0} is not installed")]
    MiniAppNotFound(String),
    #[error("Mini App session {0} does not exist")]
    MiniAppSessionNotFound(String),
    #[error("Mini App permission {0:?} was not granted")]
    MiniAppPermissionDenied(MiniAppPermission),
    #[error("Mini App request cannot be completed by the pure domain engine")]
    MiniAppHostActionRequired,
}

#[derive(Debug, Clone, Default)]
pub struct MessagingEngine {
    state: MessagingState,
}

impl MessagingEngine {
    pub fn new() -> Self {
        Self::default()
    }
    pub fn from_state(state: MessagingState) -> Self {
        Self { state }
    }
    pub fn state(&self) -> &MessagingState {
        &self.state
    }
    pub fn into_state(self) -> MessagingState {
        self.state
    }

    pub fn execute(&mut self, command: Command) -> Result<Vec<Event>, EngineError> {
        let events = self.decide(command)?;
        for event in events.iter().cloned() {
            self.apply(event);
        }
        Ok(events)
    }

    pub fn decide(&self, command: Command) -> Result<Vec<Event>, EngineError> {
        match command {
            Command::UpsertActor { actor } => {
                if !actor.id.is_valid() || actor.display_name.trim().is_empty() {
                    return Err(EngineError::InvalidActor);
                }
                Ok(vec![Event::ActorUpserted { actor }])
            }
            Command::SetPresence { actor_id, presence } => {
                self.require_actor(&actor_id)?;
                Ok(vec![Event::PresenceUpdated { actor_id, presence }])
            }
            Command::UpsertConversation { conversation } => {
                if !conversation.id.is_valid() || conversation.title.trim().is_empty() {
                    return Err(EngineError::InvalidConversation);
                }
                for participant in &conversation.participants {
                    self.require_actor(&participant.actor_id)?;
                }
                Ok(vec![Event::ConversationUpserted { conversation }])
            }
            Command::ArchiveConversation {
                conversation_id,
                archived,
            } => {
                self.require_conversation(&conversation_id)?;
                Ok(vec![Event::ConversationArchived {
                    conversation_id,
                    archived,
                }])
            }
            Command::PinConversation {
                conversation_id,
                pinned,
            } => {
                self.require_conversation(&conversation_id)?;
                Ok(vec![Event::ConversationPinned {
                    conversation_id,
                    pinned,
                }])
            }
            Command::SetConversationNotifications {
                conversation_id,
                settings,
            } => {
                self.require_conversation(&conversation_id)?;
                Ok(vec![Event::ConversationNotificationsUpdated {
                    conversation_id,
                    settings,
                }])
            }
            Command::UpsertFolder { folder } => Ok(vec![Event::FolderUpserted { folder }]),
            Command::DeleteFolder { folder_id } => Ok(vec![Event::FolderDeleted { folder_id }]),
            Command::QueueMessage {
                conversation_id,
                local_message_id,
                client_message_id,
                sender_id,
                content,
                reply_to_message_id,
                thread_root_message_id,
                created_at_ms,
                scheduled_at_ms,
                silent,
                protected_content,
            } => {
                self.require_conversation(&conversation_id)?;
                self.require_actor(&sender_id)?;
                if client_message_id.0.trim().is_empty() || client_message_id.0.len() > 200 {
                    return Err(EngineError::InvalidClientMessageId);
                }
                if self
                    .state
                    .messages
                    .get(&conversation_id)
                    .is_some_and(|messages| messages.contains_key(&local_message_id))
                {
                    return Err(EngineError::DuplicateMessage {
                        conversation_id,
                        message_id: local_message_id,
                    });
                }
                let message = Message {
                    id: local_message_id,
                    conversation_id,
                    sender_id,
                    content,
                    reply_to_message_id,
                    thread_root_message_id,
                    forward_origin: None,
                    reply_markup: None,
                    reactions: Vec::new(),
                    delivery_state: DeliveryState::Pending { client_message_id },
                    created_at_ms,
                    edited_at_ms: None,
                    scheduled_at_ms,
                    silent,
                    protected_content,
                    pinned: false,
                    deleted: false,
                };
                Ok(vec![Event::MessageQueued { message }])
            }
            Command::ForwardMessage {
                source_conversation_id,
                message_id,
                destination_conversation_id,
                local_message_id,
                client_message_id,
                sender_id,
                created_at_ms,
            } => {
                self.require_conversation(&destination_conversation_id)?;
                self.require_actor(&sender_id)?;
                if client_message_id.0.trim().is_empty() || client_message_id.0.len() > 200 {
                    return Err(EngineError::InvalidClientMessageId);
                }
                if self
                    .state
                    .messages
                    .get(&destination_conversation_id)
                    .is_some_and(|messages| messages.contains_key(&local_message_id))
                {
                    return Err(EngineError::DuplicateMessage {
                        conversation_id: destination_conversation_id,
                        message_id: local_message_id,
                    });
                }
                let original = self
                    .require_message(&source_conversation_id, &message_id)?
                    .clone();
                if original.deleted {
                    return Err(EngineError::MessageNotFound {
                        conversation_id: source_conversation_id,
                        message_id,
                    });
                }
                if original.protected_content {
                    return Err(EngineError::ProtectedContent);
                }
                let forward_origin = original
                    .forward_origin
                    .clone()
                    .unwrap_or_else(|| format!("{}:{}", original.conversation_id.0, original.id.0));
                let message = Message {
                    id: local_message_id,
                    conversation_id: destination_conversation_id,
                    sender_id,
                    content: original.content,
                    reply_to_message_id: None,
                    thread_root_message_id: None,
                    forward_origin: Some(forward_origin),
                    reply_markup: original.reply_markup,
                    reactions: Vec::new(),
                    delivery_state: DeliveryState::Pending { client_message_id },
                    created_at_ms,
                    edited_at_ms: None,
                    scheduled_at_ms: None,
                    silent: false,
                    protected_content: original.protected_content,
                    pinned: false,
                    deleted: false,
                };
                Ok(vec![Event::MessageQueued { message }])
            }
            Command::AcknowledgeMessage {
                conversation_id,
                local_message_id,
                server_message_id,
                accepted_at_ms,
            } => {
                self.require_message(&conversation_id, &local_message_id)?;
                if local_message_id != server_message_id
                    && self
                        .state
                        .messages
                        .get(&conversation_id)
                        .is_some_and(|messages| messages.contains_key(&server_message_id))
                {
                    return Err(EngineError::DuplicateMessage {
                        conversation_id,
                        message_id: server_message_id,
                    });
                }
                Ok(vec![Event::MessageAcknowledged {
                    conversation_id,
                    local_message_id,
                    server_message_id,
                    accepted_at_ms,
                }])
            }
            Command::SetDeliveryState {
                conversation_id,
                message_id,
                state,
            } => {
                self.require_message(&conversation_id, &message_id)?;
                Ok(vec![Event::DeliveryStateUpdated {
                    conversation_id,
                    message_id,
                    state,
                }])
            }
            Command::EditMessage {
                conversation_id,
                message_id,
                content,
                edited_at_ms,
            } => {
                self.require_message(&conversation_id, &message_id)?;
                Ok(vec![Event::MessageEdited {
                    conversation_id,
                    message_id,
                    content,
                    edited_at_ms,
                }])
            }
            Command::DeleteMessages {
                conversation_id,
                message_ids,
            } => {
                let unique: BTreeSet<_> = message_ids.into_iter().collect();
                if unique.is_empty() {
                    return Err(EngineError::EmptyMessageList);
                }
                for id in &unique {
                    self.require_message(&conversation_id, id)?;
                }
                Ok(vec![Event::MessagesDeleted {
                    conversation_id,
                    message_ids: unique.into_iter().collect(),
                }])
            }
            Command::MarkRead {
                conversation_id,
                actor_id,
                message_id,
            } => {
                self.require_actor(&actor_id)?;
                self.require_message(&conversation_id, &message_id)?;
                Ok(vec![Event::ConversationRead {
                    conversation_id,
                    actor_id,
                    message_id,
                }])
            }
            Command::SetReaction {
                conversation_id,
                message_id,
                reaction,
            } => {
                self.require_message(&conversation_id, &message_id)?;
                if reaction.reaction.trim().is_empty() {
                    return Err(EngineError::InvalidClientMessageId);
                }
                Ok(vec![Event::ReactionUpdated {
                    conversation_id,
                    message_id,
                    reaction,
                }])
            }
            Command::PinMessage {
                conversation_id,
                message_id,
                pinned,
            } => {
                self.require_message(&conversation_id, &message_id)?;
                Ok(vec![Event::MessagePinned {
                    conversation_id,
                    message_id,
                    pinned,
                }])
            }
            Command::CreateInvoice { invoice } => {
                if !invoice.is_valid() {
                    return Err(EngineError::InvalidInvoice);
                }
                self.require_actor(&invoice.seller_id)?;
                self.require_conversation(&invoice.conversation_id)?;
                Ok(vec![Event::InvoiceCreated { invoice }])
            }
            Command::UpsertOrder { order } => {
                if !self.state.invoices.contains_key(&order.invoice_id) {
                    return Err(EngineError::InvoiceNotFound(order.invoice_id));
                }
                self.require_actor(&order.buyer_id)?;
                Ok(vec![Event::OrderUpserted { order }])
            }
            Command::InstallMiniApp { manifest } => Ok(vec![Event::MiniAppInstalled { manifest }]),
            Command::GrantMiniApp { grant } => {
                if !self.state.mini_apps.contains_key(&grant.mini_app_id) {
                    return Err(EngineError::MiniAppNotFound(grant.mini_app_id));
                }
                self.require_actor(&grant.actor_id)?;
                Ok(vec![Event::MiniAppGrantUpdated { grant }])
            }
            Command::OpenMiniApp { session } => {
                if !self.state.mini_apps.contains_key(&session.mini_app_id) {
                    return Err(EngineError::MiniAppNotFound(session.mini_app_id));
                }
                let grant = self
                    .state
                    .mini_app_grants
                    .get(&(session.mini_app_id.clone(), session.actor_id.clone()));
                if session.granted_permissions.iter().any(|permission| {
                    !grant.is_some_and(|grant| grant.permissions.contains(permission))
                }) {
                    return Err(EngineError::MiniAppPermissionDenied(
                        *session
                            .granted_permissions
                            .iter()
                            .find(|permission| {
                                !grant.is_some_and(|grant| grant.permissions.contains(permission))
                            })
                            .expect("permission exists"),
                    ));
                }
                Ok(vec![Event::MiniAppOpened { session }])
            }
            Command::MiniAppCall {
                session_id,
                request_id,
                request,
            } => {
                let session = self
                    .state
                    .mini_app_sessions
                    .get(&session_id)
                    .ok_or_else(|| EngineError::MiniAppSessionNotFound(session_id.clone()))?;
                if let Some(permission) = request.required_permission() {
                    if !session.granted_permissions.contains(&permission) {
                        return Err(EngineError::MiniAppPermissionDenied(permission));
                    }
                }
                let response = match request {
                    MiniAppRequest::Ready
                    | MiniAppRequest::Expand
                    | MiniAppRequest::Close
                    | MiniAppRequest::SetHeaderColor { .. }
                    | MiniAppRequest::SetBackgroundColor { .. } => MiniAppResponse::Ok,
                    _ => return Err(EngineError::MiniAppHostActionRequired),
                };
                Ok(vec![Event::MiniAppResponded {
                    session_id,
                    request_id,
                    response,
                }])
            }
        }
    }

    pub fn apply(&mut self, event: Event) {
        match event {
            Event::ActorUpserted { actor } => {
                self.state.actors.insert(actor.id.clone(), actor);
            }
            Event::PresenceUpdated { actor_id, presence } => {
                if let Some(actor) = self.state.actors.get_mut(&actor_id) {
                    actor.presence = presence;
                }
            }
            Event::ConversationUpserted { conversation } => {
                self.state
                    .conversations
                    .insert(conversation.id.clone(), conversation);
            }
            Event::ConversationArchived {
                conversation_id,
                archived,
            } => {
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    conversation.archived = archived;
                }
            }
            Event::ConversationPinned {
                conversation_id,
                pinned,
            } => {
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    conversation.pinned = pinned;
                }
            }
            Event::ConversationNotificationsUpdated {
                conversation_id,
                settings,
            } => {
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    conversation.notification_settings = settings;
                }
            }
            Event::FolderUpserted { folder } => {
                self.state.folders.insert(folder.id.clone(), folder);
            }
            Event::FolderDeleted { folder_id } => {
                self.state.folders.remove(&folder_id);
                for conversation in self.state.conversations.values_mut() {
                    conversation.folder_ids.retain(|id| id != &folder_id);
                }
            }
            Event::MessageQueued { message } => {
                if let Some(conversation) =
                    self.state.conversations.get_mut(&message.conversation_id)
                {
                    conversation.last_message_id = Some(message.id.0.clone());
                    conversation.updated_at_ms = message.created_at_ms;
                }
                self.state
                    .messages
                    .entry(message.conversation_id.clone())
                    .or_default()
                    .insert(message.id.clone(), message);
            }
            Event::MessageAcknowledged {
                conversation_id,
                local_message_id,
                server_message_id,
                accepted_at_ms,
            } => {
                if let Some(messages) = self.state.messages.get_mut(&conversation_id) {
                    if let Some(mut message) = messages.remove(&local_message_id) {
                        message.id = server_message_id.clone();
                        message.delivery_state = DeliveryState::Sent;
                        message.created_at_ms = accepted_at_ms;
                        messages.insert(server_message_id.clone(), message);
                    }
                }
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    if conversation.last_message_id.as_deref() == Some(local_message_id.0.as_str())
                    {
                        conversation.last_message_id = Some(server_message_id.0);
                    }
                }
            }
            Event::DeliveryStateUpdated {
                conversation_id,
                message_id,
                state,
            } => {
                if let Some(message) = self
                    .state
                    .messages
                    .get_mut(&conversation_id)
                    .and_then(|messages| messages.get_mut(&message_id))
                {
                    message.delivery_state = state;
                }
            }
            Event::MessageEdited {
                conversation_id,
                message_id,
                content,
                edited_at_ms,
            } => {
                if let Some(message) = self
                    .state
                    .messages
                    .get_mut(&conversation_id)
                    .and_then(|messages| messages.get_mut(&message_id))
                {
                    message.content = content;
                    message.edited_at_ms = Some(edited_at_ms);
                }
            }
            Event::MessagesDeleted {
                conversation_id,
                message_ids,
            } => {
                if let Some(messages) = self.state.messages.get_mut(&conversation_id) {
                    for id in message_ids {
                        if let Some(message) = messages.get_mut(&id) {
                            message.deleted = true;
                        }
                    }
                }
            }
            Event::ConversationRead {
                conversation_id,
                message_id,
                ..
            } => {
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    conversation.last_read_message_id = Some(message_id.0);
                    conversation.unread_count = 0;
                    conversation.marked_unread = false;
                }
            }
            Event::ReactionUpdated {
                conversation_id,
                message_id,
                reaction,
            } => {
                if let Some(message) = self
                    .state
                    .messages
                    .get_mut(&conversation_id)
                    .and_then(|messages| messages.get_mut(&message_id))
                {
                    message
                        .reactions
                        .retain(|item| item.reaction != reaction.reaction);
                    if reaction.count > 0 {
                        message.reactions.push(reaction);
                    }
                }
            }
            Event::MessagePinned {
                conversation_id,
                message_id,
                pinned,
            } => {
                if let Some(message) = self
                    .state
                    .messages
                    .get_mut(&conversation_id)
                    .and_then(|messages| messages.get_mut(&message_id))
                {
                    message.pinned = pinned;
                }
                if let Some(conversation) = self.state.conversations.get_mut(&conversation_id) {
                    conversation
                        .pinned_message_ids
                        .retain(|id| id != &message_id.0);
                    if pinned {
                        conversation.pinned_message_ids.push(message_id.0);
                    }
                }
            }
            Event::InvoiceCreated { invoice } => {
                self.state.invoices.insert(invoice.id.clone(), invoice);
            }
            Event::OrderUpserted { order } => {
                self.state.orders.insert(order.id.clone(), order);
            }
            Event::MiniAppInstalled { manifest } => {
                self.state.mini_apps.insert(manifest.id.clone(), manifest);
            }
            Event::MiniAppGrantUpdated { grant } => {
                self.state
                    .mini_app_grants
                    .insert((grant.mini_app_id.clone(), grant.actor_id.clone()), grant);
            }
            Event::MiniAppOpened { session } => {
                self.state
                    .mini_app_sessions
                    .insert(session.id.clone(), session);
            }
            Event::MiniAppResponded { .. } => {}
        }
    }

    pub fn complete_paid_order(
        &mut self,
        order_id: &str,
        updated_at_ms: i64,
    ) -> Result<Vec<Event>, EngineError> {
        let mut order = self
            .state
            .orders
            .get(order_id)
            .cloned()
            .ok_or_else(|| EngineError::OrderNotFound(order_id.to_string()))?;
        order.status = PaymentStatus::Paid;
        order.updated_at_ms = updated_at_ms;
        self.execute(Command::UpsertOrder { order })
    }

    fn require_actor(&self, id: &ActorId) -> Result<&Actor, EngineError> {
        self.state
            .actors
            .get(id)
            .ok_or_else(|| EngineError::ActorNotFound(id.clone()))
    }
    fn require_conversation(&self, id: &ConversationId) -> Result<&Conversation, EngineError> {
        self.state
            .conversations
            .get(id)
            .ok_or_else(|| EngineError::ConversationNotFound(id.clone()))
    }
    fn require_message(
        &self,
        conversation_id: &ConversationId,
        message_id: &MessageId,
    ) -> Result<&Message, EngineError> {
        self.state
            .messages
            .get(conversation_id)
            .and_then(|messages| messages.get(message_id))
            .ok_or_else(|| EngineError::MessageNotFound {
                conversation_id: conversation_id.clone(),
                message_id: message_id.clone(),
            })
    }
}
