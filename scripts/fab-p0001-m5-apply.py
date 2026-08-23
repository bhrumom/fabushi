from pathlib import Path


def replace_once(path: str, old: str, new: str) -> None:
    target = Path(path)
    text = target.read_text()
    if new in text:
        return
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one patch anchor, found {count}")
    target.write_text(text.replace(old, new, 1))


# Protocol: expose the existing search index through the Fabushi-owned wire contract.
replace_once(
    "native/mahayana-messaging/src/protocol.rs",
    "use crate::payment::{CustomerInfo, Invoice, PaymentOrder};\nuse crate::story::{Story, StoryId};\n",
    "use crate::payment::{CustomerInfo, Invoice, PaymentOrder};\nuse crate::search::{SearchQuery, SearchResult};\nuse crate::story::{Story, StoryId};\n",
)
replace_once(
    "native/mahayana-messaging/src/protocol.rs",
    '''    Sync {
        cursor: Option<String>,
        limit: u32,
    },
    UpsertProfile {
''',
    '''    Sync {
        cursor: Option<String>,
        limit: u32,
    },
    Search {
        query: SearchQuery,
    },
    UpsertProfile {
''',
)
replace_once(
    "native/mahayana-messaging/src/protocol.rs",
    '''        next_cursor: Option<String>,
    },
    ActorChanged {
''',
    '''        next_cursor: Option<String>,
    },
    SearchResults {
        query: SearchQuery,
        results: Vec<SearchResult>,
    },
    ActorChanged {
''',
)

# Service: search is read-only, actor-aware, and never creates a second contact state store.
replace_once(
    "native/mahayana-messaging/src/service.rs",
    "use crate::protocol::{\n    ClientCommand, ClientEnvelope, ServerEnvelope, ServerEvent, FABUSHI_MESSAGING_PROTOCOL_VERSION,\n};\n",
    "use crate::protocol::{\n    ClientCommand, ClientEnvelope, ServerEnvelope, ServerEvent, FABUSHI_MESSAGING_PROTOCOL_VERSION,\n};\nuse crate::search::{SearchIndex, SearchQuery};\n",
)
replace_once(
    "native/mahayana-messaging/src/service.rs",
    '''            ClientCommand::Sync { cursor, limit } => {
                self.mark_direct_messages_delivered(&actor_id, server_time_ms)?;
                self.sync_response(&actor_id, cursor.as_deref(), limit, server_time_ms)
            }
            ClientCommand::StartTyping {
''',
    '''            ClientCommand::Sync { cursor, limit } => {
                self.mark_direct_messages_delivered(&actor_id, server_time_ms)?;
                self.sync_response(&actor_id, cursor.as_deref(), limit, server_time_ms)
            }
            ClientCommand::Search { query } => {
                Ok(vec![self.search_envelope(&actor_id, query, server_time_ms)])
            }
            ClientCommand::StartTyping {
''',
)
replace_once(
    "native/mahayana-messaging/src/service.rs",
    '''    fn typing_event(
''',
    '''    fn search_envelope(
        &self,
        actor_id: &ActorId,
        query: SearchQuery,
        server_time_ms: i64,
    ) -> ServerEnvelope {
        let state = self.engine.state();
        let visible_conversations = state
            .conversations
            .values()
            .filter(|conversation| {
                conversation.owner_id.as_ref() == Some(actor_id)
                    || conversation
                        .participants
                        .iter()
                        .any(|participant| &participant.actor_id == actor_id)
                    || state
                        .communities
                        .get(&conversation.id)
                        .and_then(|community| community.public_username.as_ref())
                        .is_some()
            })
            .map(|conversation| conversation.id.clone())
            .collect::<BTreeSet<_>>();
        let mut index = SearchIndex::default();
        for actor in state.actors.values().cloned() {
            index.index_actor(actor);
        }
        for conversation in state
            .conversations
            .values()
            .filter(|conversation| visible_conversations.contains(&conversation.id))
            .cloned()
        {
            index.index_conversation(conversation);
        }
        for message in visible_conversations
            .iter()
            .filter_map(|conversation_id| state.messages.get(conversation_id))
            .flat_map(|messages| messages.values())
            .filter(|message| !message.deleted)
            .cloned()
        {
            index.index_message(message);
        }
        let results = index.search(&query);
        ServerEnvelope {
            protocol_version: FABUSHI_MESSAGING_PROTOCOL_VERSION,
            cursor: Some(self.cursor.to_string()),
            server_time_ms,
            event: ServerEvent::SearchResults { query, results },
        }
    }

    fn typing_event(
''',
)

# Engine: operation-specific community rights + restricted member send enforcement.
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''    #[error("community administration permission denied")]
    CommunityPermissionDenied,
    #[error(transparent)]
''',
    '''    #[error("community administration permission denied")]
    CommunityPermissionDenied,
    #[error("community {0:?} member is not allowed to send messages")]
    CommunitySendRestricted(ConversationId),
    #[error("community {0:?} member is not allowed to send media")]
    CommunityMediaRestricted(ConversationId),
    #[error("community {0:?} member is not allowed to send polls")]
    CommunityPollRestricted(ConversationId),
    #[error(transparent)]
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''fn require_community_admin(
    community: &CommunityState,
    actor_id: &ActorId,
) -> Result<(), EngineError> {
    let allowed = community.members.get(actor_id).is_some_and(|member| {
        matches!(member.status, MemberStatus::Owner)
            || (matches!(member.status, MemberStatus::Administrator)
                && (member.admin_rights.change_info
                    || member.admin_rights.ban_members
                    || member.admin_rights.invite_members
                    || member.admin_rights.manage_topics
                    || member.admin_rights.add_admins))
    });
    if allowed {
        Ok(())
    } else {
        Err(EngineError::CommunityPermissionDenied)
    }
}
''',
    '''#[derive(Debug, Clone, Copy)]
enum CommunityAdminAction {
    ChangeInfo,
    InviteMembers,
    BanMembers,
    ManageTopics,
    AddAdmins,
}

fn is_community_owner(community: &CommunityState, actor_id: &ActorId) -> bool {
    community
        .members
        .get(actor_id)
        .is_some_and(|member| matches!(member.status, MemberStatus::Owner))
}

fn require_community_admin(
    community: &CommunityState,
    actor_id: &ActorId,
    action: CommunityAdminAction,
) -> Result<(), EngineError> {
    let allowed = community.members.get(actor_id).is_some_and(|member| {
        if matches!(member.status, MemberStatus::Owner) {
            return true;
        }
        if !matches!(member.status, MemberStatus::Administrator) {
            return false;
        }
        match action {
            CommunityAdminAction::ChangeInfo => member.admin_rights.change_info,
            CommunityAdminAction::InviteMembers => member.admin_rights.invite_members,
            CommunityAdminAction::BanMembers => member.admin_rights.ban_members,
            CommunityAdminAction::ManageTopics => member.admin_rights.manage_topics,
            CommunityAdminAction::AddAdmins => member.admin_rights.add_admins,
        }
    });
    if allowed {
        Ok(())
    } else {
        Err(EngineError::CommunityPermissionDenied)
    }
}
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                if matches!(&content, MessageContent::Poll { .. })
                    && !conversation.permissions.can_send_polls
                {
                    return Err(EngineError::PollSendPermissionDenied(
                        conversation_id.clone(),
                    ));
                }
                let is_secret_conversation = matches!(
''',
    '''                if matches!(&content, MessageContent::Poll { .. })
                    && !conversation.permissions.can_send_polls
                {
                    return Err(EngineError::PollSendPermissionDenied(
                        conversation_id.clone(),
                    ));
                }
                if let Some(member) = self
                    .state
                    .communities
                    .get(&conversation_id)
                    .and_then(|community| community.members.get(&sender_id))
                {
                    if matches!(member.status, MemberStatus::Left | MemberStatus::Banned)
                        || (matches!(member.status, MemberStatus::Restricted)
                            && member.restrictions.send_messages)
                    {
                        return Err(EngineError::CommunitySendRestricted(
                            conversation_id.clone(),
                        ));
                    }
                    if message_content_uses_media(&content)
                        && matches!(member.status, MemberStatus::Restricted)
                        && member.restrictions.send_media
                    {
                        return Err(EngineError::CommunityMediaRestricted(
                            conversation_id.clone(),
                        ));
                    }
                    if matches!(&content, MessageContent::Poll { .. })
                        && matches!(member.status, MemberStatus::Restricted)
                        && member.restrictions.send_polls
                    {
                        return Err(EngineError::CommunityPollRestricted(
                            conversation_id.clone(),
                        ));
                    }
                }
                let is_secret_conversation = matches!(
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                if let Some(existing) = self.state.communities.get(&community.conversation_id) {
                    require_community_admin(existing, &actor_id)?;
                } else if conversation.owner_id.as_ref() != Some(&actor_id)
''',
    '''                if let Some(existing) = self.state.communities.get(&community.conversation_id) {
                    require_community_admin(
                        existing,
                        &actor_id,
                        CommunityAdminAction::ChangeInfo,
                    )?;
                } else if conversation.owner_id.as_ref() != Some(&actor_id)
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                community.upsert_member(member);
                Ok(vec![Event::CommunityChanged { community }])
            }
            Command::CreateInviteLink { actor_id, invite } => {
''',
    '''                let caller_is_owner = is_community_owner(&community, &actor_id);
                let target_is_owner = community
                    .members
                    .get(&member.actor_id)
                    .is_some_and(|existing| matches!(existing.status, MemberStatus::Owner));
                if (target_is_owner || matches!(member.status, MemberStatus::Owner))
                    && !caller_is_owner
                {
                    return Err(EngineError::CommunityPermissionDenied);
                }
                let action = match member.status {
                    MemberStatus::Owner | MemberStatus::Administrator => {
                        CommunityAdminAction::AddAdmins
                    }
                    MemberStatus::Restricted | MemberStatus::Left | MemberStatus::Banned => {
                        CommunityAdminAction::BanMembers
                    }
                    MemberStatus::Member => CommunityAdminAction::InviteMembers,
                };
                require_community_admin(&community, &actor_id, action)?;
                community.upsert_member(member);
                Ok(vec![Event::CommunityChanged { community }])
            }
            Command::CreateInviteLink { actor_id, invite } => {
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                if invite.creator_id != actor_id
''',
    '''                require_community_admin(
                    &community,
                    &actor_id,
                    CommunityAdminAction::InviteMembers,
                )?;
                if invite.creator_id != actor_id
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                community.revoke_invite(&invite_id)?;
''',
    '''                require_community_admin(
                    &community,
                    &actor_id,
                    CommunityAdminAction::InviteMembers,
                )?;
                community.revoke_invite(&invite_id)?;
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                if approved {
''',
    '''                require_community_admin(
                    &community,
                    &actor_id,
                    CommunityAdminAction::InviteMembers,
                )?;
                if approved {
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                if topic.id.trim().is_empty() {
''',
    '''                require_community_admin(
                    &community,
                    &actor_id,
                    CommunityAdminAction::ManageTopics,
                )?;
                if topic.id.trim().is_empty() {
''',
)
replace_once(
    "native/mahayana-messaging/src/engine.rs",
    '''                require_community_admin(&community, &actor_id)?;
                community.topics.remove(&topic_id);
''',
    '''                require_community_admin(
                    &community,
                    &actor_id,
                    CommunityAdminAction::ManageTopics,
                )?;
                community.topics.remove(&topic_id);
''',
)
