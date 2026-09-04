use fabushi_messaging_core::*;

fn context(actor_id: &str, request_id: &str) -> RequestContext {
    RequestContext {
        request_id: request_id.into(),
        device_id: format!("device:{actor_id}"),
        actor_id: ActorId::new(actor_id),
        session_id: format!("session:{actor_id}"),
        sent_at_ms: 1,
    }
}

fn participant(actor_id: &str, role: ParticipantRole) -> Participant {
    Participant {
        actor_id: ActorId::new(actor_id),
        role,
        joined_at_ms: 1,
        muted_until_ms: None,
    }
}

fn channel_conversation() -> Conversation {
    let mut conversation = Conversation::direct(
        "channel:m6",
        "M6 Dharma Channel",
        vec![
            participant("human:owner", ParticipantRole::Owner),
            participant("human:admin", ParticipantRole::Admin),
        ],
        1,
    );
    conversation.kind = ConversationKind::Channel;
    conversation.owner_id = Some(ActorId::new("human:owner"));
    conversation
}

fn channel_community() -> CommunityState {
    let mut community = CommunityState::new(ConversationId::new("channel:m6"));
    community.public_username = Some("m6".into());
    community.upsert_member(CommunityMember {
        actor_id: ActorId::new("human:owner"),
        status: MemberStatus::Owner,
        admin_title: Some("Owner".into()),
        admin_rights: AdminRights::default(),
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 1,
        invited_by: None,
    });
    community.upsert_member(CommunityMember {
        actor_id: ActorId::new("human:admin"),
        status: MemberStatus::Administrator,
        admin_title: Some("Publisher".into()),
        admin_rights: AdminRights {
            post_messages: true,
            manage_topics: true,
            change_info: true,
            ban_members: true,
            ..AdminRights::default()
        },
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 1,
        invited_by: Some(ActorId::new("human:owner")),
    });
    community
}

fn text_message(text: &str) -> MessageContent {
    MessageContent::Text {
        text: FormattedText::plain(text),
    }
}

fn sync_batch(events: &[ServerEnvelope]) -> &ServerEvent {
    events
        .iter()
        .find_map(|envelope| match &envelope.event {
            ServerEvent::SyncBatch { .. } => Some(&envelope.event),
            _ => None,
        })
        .expect("sync response")
}

#[test]
fn channel_subscription_broadcast_pagination_and_topic_state_are_actor_scoped() {
    let mut service = MessagingService::load(MemoryStateStore::default()).unwrap();
    for actor_id in [
        "human:owner",
        "human:admin",
        "human:subscriber",
        "human:outsider",
    ] {
        service
            .handle(
                ClientEnvelope::new(
                    context(actor_id, &format!("profile:{actor_id}")),
                    ClientCommand::UpsertProfile {
                        actor: Actor::human(actor_id, actor_id),
                    },
                ),
                1,
            )
            .unwrap();
    }

    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "create-channel"),
                ClientCommand::CreateConversation {
                    conversation: channel_conversation(),
                },
            ),
            2,
        )
        .unwrap();
    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "create-community"),
                ClientCommand::UpdateCommunity {
                    community: channel_community(),
                },
            ),
            3,
        )
        .unwrap();
    service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "subscribe"),
                ClientCommand::SubscribeChannel {
                    conversation_id: ConversationId::new("channel:m6"),
                },
            ),
            4,
        )
        .unwrap();

    let members_page = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "members-1"),
                ClientCommand::ListCommunityMembers {
                    conversation_id: ConversationId::new("channel:m6"),
                    cursor: None,
                    limit: 1,
                },
            ),
            5,
        )
        .unwrap();
    let next_cursor = match &members_page[0].event {
        ServerEvent::CommunityMembersPage {
            members,
            next_cursor,
            ..
        } => {
            assert_eq!(members.len(), 1);
            next_cursor.clone().expect("member page cursor")
        }
        event => panic!("unexpected member page: {event:?}"),
    };
    let members_page_2 = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "members-2"),
                ClientCommand::ListCommunityMembers {
                    conversation_id: ConversationId::new("channel:m6"),
                    cursor: Some(next_cursor),
                    limit: 10,
                },
            ),
            6,
        )
        .unwrap();
    assert!(matches!(
        &members_page_2[0].event,
        ServerEvent::CommunityMembersPage { members, .. } if members.len() == 2
    ));

    let subscriber_audit_denied = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "audit-denied"),
                ClientCommand::ListCommunityAuditLog {
                    conversation_id: ConversationId::new("channel:m6"),
                    cursor: None,
                    limit: 100,
                },
            ),
            7,
        )
        .unwrap_err();
    assert!(matches!(
        subscriber_audit_denied,
        MessagingServiceError::UnauthorizedCommand(_)
    ));

    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "publish"),
                ClientCommand::SendMessage {
                    conversation_id: ConversationId::new("channel:m6"),
                    client_message_id: ClientMessageId("client:publish".into()),
                    content: text_message("broadcast"),
                    reply_to_message_id: None,
                    thread_root_message_id: None,
                    scheduled_at_ms: None,
                    silent: false,
                    protected_content: false,
                },
            ),
            8,
        )
        .unwrap();

    let subscriber_sync = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "sync-subscriber"),
                ClientCommand::Sync {
                    cursor: None,
                    limit: 100,
                },
            ),
            9,
        )
        .unwrap();
    match sync_batch(&subscriber_sync) {
        ServerEvent::SyncBatch {
            conversations,
            messages,
            communities,
            ..
        } => {
            assert!(conversations
                .iter()
                .any(|conversation| conversation.id == ConversationId::new("channel:m6")));
            assert!(messages
                .iter()
                .any(|message| { message.conversation_id == ConversationId::new("channel:m6") }));
            assert!(communities.iter().any(|community| {
                community.conversation_id == ConversationId::new("channel:m6")
                    && community.admin_log.is_empty()
            }));
        }
        event => panic!("unexpected subscriber sync: {event:?}"),
    }

    let outsider_sync = service
        .handle(
            ClientEnvelope::new(
                context("human:outsider", "sync-outsider"),
                ClientCommand::Sync {
                    cursor: None,
                    limit: 100,
                },
            ),
            10,
        )
        .unwrap();
    match sync_batch(&outsider_sync) {
        ServerEvent::SyncBatch {
            conversations,
            messages,
            ..
        } => {
            assert!(conversations.is_empty());
            assert!(messages.is_empty());
        }
        event => panic!("unexpected outsider sync: {event:?}"),
    }

    let audit = service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "audit-owner"),
                ClientCommand::ListCommunityAuditLog {
                    conversation_id: ConversationId::new("channel:m6"),
                    cursor: None,
                    limit: 100,
                },
            ),
            11,
        )
        .unwrap();
    assert!(matches!(
        &audit[0].event,
        ServerEvent::CommunityAuditLogPage { entries, .. }
            if entries.iter().any(|entry| entry.action == CommunityAuditAction::SubscriptionAdded)
    ));

    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "topic-create"),
                ClientCommand::UpsertForumTopic {
                    topic: ForumTopicState {
                        id: "study".into(),
                        conversation_id: ConversationId::new("channel:m6"),
                        title: "Study".into(),
                        icon: None,
                        creator_id: ActorId::new("human:owner"),
                        created_at_ms: 12,
                        pinned: false,
                        closed: false,
                        hidden: false,
                        unread_count: 0,
                        last_message_id: None,
                    },
                },
            ),
            12,
        )
        .unwrap();
    let topic_message = service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "topic-post"),
                ClientCommand::SendMessage {
                    conversation_id: ConversationId::new("channel:m6"),
                    client_message_id: ClientMessageId("client:topic".into()),
                    content: text_message("topic post"),
                    reply_to_message_id: None,
                    thread_root_message_id: Some(MessageId::new("topic:study")),
                    scheduled_at_ms: None,
                    silent: false,
                    protected_content: false,
                },
            ),
            13,
        )
        .unwrap()
        .into_iter()
        .find_map(|envelope| match envelope.event {
            ServerEvent::MessageAdded { message } => Some(message.id),
            _ => None,
        })
        .expect("topic message");

    let topic_before_read = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "topic-sync-before-read"),
                ClientCommand::Sync {
                    cursor: None,
                    limit: 100,
                },
            ),
            14,
        )
        .unwrap();
    assert!(matches!(
        sync_batch(&topic_before_read),
        ServerEvent::SyncBatch { conversations, .. }
            if conversations.iter().any(|conversation| {
                conversation.id == ConversationId::new("channel:m6")
                    && conversation.topics.iter().any(|topic| {
                        topic.id == "study" && topic.unread_count == 1
                    })
            })
    ));

    service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "topic-draft"),
                ClientCommand::SetTopicDraft {
                    conversation_id: ConversationId::new("channel:m6"),
                    topic_id: "study".into(),
                    text: "draft".into(),
                    reply_to_message_id: None,
                },
            ),
            15,
        )
        .unwrap();
    service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "topic-read"),
                ClientCommand::MarkTopicRead {
                    conversation_id: ConversationId::new("channel:m6"),
                    topic_id: "study".into(),
                    message_id: topic_message,
                },
            ),
            16,
        )
        .unwrap();
    let topic_after_read = service
        .handle(
            ClientEnvelope::new(
                context("human:subscriber", "topic-sync-after-read"),
                ClientCommand::Sync {
                    cursor: None,
                    limit: 100,
                },
            ),
            17,
        )
        .unwrap();
    assert!(matches!(
        sync_batch(&topic_after_read),
        ServerEvent::SyncBatch {
            conversations,
            topic_drafts,
            ..
        } if conversations.iter().any(|conversation| {
            conversation.id == ConversationId::new("channel:m6")
                && conversation.topics.iter().any(|topic| {
                    topic.id == "study" && topic.unread_count == 0
                })
        }) && topic_drafts.iter().any(|draft| draft.topic_id == "study")
    ));
}

#[test]
fn slow_mode_and_moderation_are_enforced_by_the_rust_state_machine() {
    let mut engine = MessagingEngine::new();
    for actor_id in ["human:owner", "human:admin", "human:member"] {
        engine
            .execute(Command::UpsertActor {
                actor: Actor::human(actor_id, actor_id),
            })
            .unwrap();
    }

    let mut conversation = Conversation::direct(
        "group:m6",
        "M6 Study Group",
        vec![
            participant("human:owner", ParticipantRole::Owner),
            participant("human:admin", ParticipantRole::Admin),
            participant("human:member", ParticipantRole::Member),
        ],
        1,
    );
    conversation.kind = ConversationKind::Group;
    conversation.owner_id = Some(ActorId::new("human:owner"));
    engine
        .execute(Command::UpsertConversation { conversation })
        .unwrap();

    let mut community = CommunityState::new(ConversationId::new("group:m6"));
    community.upsert_member(CommunityMember {
        actor_id: ActorId::new("human:owner"),
        status: MemberStatus::Owner,
        admin_title: None,
        admin_rights: AdminRights::default(),
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 1,
        invited_by: None,
    });
    community.upsert_member(CommunityMember {
        actor_id: ActorId::new("human:admin"),
        status: MemberStatus::Administrator,
        admin_title: None,
        admin_rights: AdminRights {
            manage_topics: true,
            ban_members: true,
            ..AdminRights::default()
        },
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 1,
        invited_by: Some(ActorId::new("human:owner")),
    });
    community.upsert_member(CommunityMember {
        actor_id: ActorId::new("human:member"),
        status: MemberStatus::Member,
        admin_title: None,
        admin_rights: AdminRights::default(),
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 1,
        invited_by: Some(ActorId::new("human:owner")),
    });
    engine
        .execute(Command::UpdateCommunity {
            actor_id: ActorId::new("human:owner"),
            community,
        })
        .unwrap();

    engine
        .execute(Command::SetCommunitySlowMode {
            actor_id: ActorId::new("human:owner"),
            conversation_id: ConversationId::new("group:m6"),
            seconds: Some(10),
            changed_at_ms: 10,
        })
        .unwrap();
    let admin_slow_mode_denied = engine
        .execute(Command::SetCommunitySlowMode {
            actor_id: ActorId::new("human:admin"),
            conversation_id: ConversationId::new("group:m6"),
            seconds: Some(20),
            changed_at_ms: 11,
        })
        .unwrap_err();
    assert_eq!(
        admin_slow_mode_denied,
        EngineError::CommunityPermissionDenied
    );

    engine
        .execute(Command::QueueMessage {
            conversation_id: ConversationId::new("group:m6"),
            local_message_id: MessageId::new("message:m6:first"),
            client_message_id: ClientMessageId("client:m6:first".into()),
            sender_id: ActorId::new("human:member"),
            content: text_message("first"),
            reply_to_message_id: None,
            thread_root_message_id: None,
            created_at_ms: 100,
            scheduled_at_ms: None,
            silent: false,
            protected_content: false,
        })
        .unwrap();
    let slow_mode_error = engine
        .execute(Command::QueueMessage {
            conversation_id: ConversationId::new("group:m6"),
            local_message_id: MessageId::new("message:m6:second"),
            client_message_id: ClientMessageId("client:m6:second".into()),
            sender_id: ActorId::new("human:member"),
            content: text_message("second"),
            reply_to_message_id: None,
            thread_root_message_id: None,
            created_at_ms: 500,
            scheduled_at_ms: None,
            silent: false,
            protected_content: false,
        })
        .unwrap_err();
    assert!(matches!(
        slow_mode_error,
        EngineError::SlowModeActive {
            conversation_id,
            retry_at_ms: 10_100
        } if conversation_id == ConversationId::new("group:m6")
    ));

    engine
        .execute(Command::UpsertForumTopic {
            actor_id: ActorId::new("human:admin"),
            topic: ForumTopicState {
                id: "study".into(),
                conversation_id: ConversationId::new("group:m6"),
                title: "Study".into(),
                icon: None,
                creator_id: ActorId::new("human:admin"),
                created_at_ms: 10_100,
                pinned: false,
                closed: false,
                hidden: false,
                unread_count: 0,
                last_message_id: None,
            },
        })
        .unwrap();
    let topic_message_id = MessageId::new("message:m6:topic");
    engine
        .execute(Command::QueueMessage {
            conversation_id: ConversationId::new("group:m6"),
            local_message_id: topic_message_id.clone(),
            client_message_id: ClientMessageId("client:m6:topic".into()),
            sender_id: ActorId::new("human:member"),
            content: text_message("topic"),
            reply_to_message_id: None,
            thread_root_message_id: Some(MessageId::new("topic:study")),
            created_at_ms: 10_100,
            scheduled_at_ms: None,
            silent: false,
            protected_content: false,
        })
        .unwrap();
    engine
        .execute(Command::MarkTopicRead {
            conversation_id: ConversationId::new("group:m6"),
            topic_id: "study".into(),
            actor_id: ActorId::new("human:member"),
            message_id: topic_message_id,
        })
        .unwrap();
    engine
        .execute(Command::SetTopicDraft {
            draft: TopicDraft {
                conversation_id: ConversationId::new("group:m6"),
                topic_id: "study".into(),
                actor_id: ActorId::new("human:member"),
                text: "draft".into(),
                reply_to_message_id: None,
                updated_at_ms: 10_101,
            },
        })
        .unwrap();

    let banned_member = CommunityMember {
        actor_id: ActorId::new("human:member"),
        status: MemberStatus::Banned,
        admin_title: None,
        admin_rights: AdminRights::default(),
        restrictions: MemberRestrictions::default(),
        joined_at_ms: 10_102,
        invited_by: Some(ActorId::new("human:owner")),
    };
    engine
        .execute(Command::ModerateCommunityMember {
            actor_id: ActorId::new("human:admin"),
            conversation_id: ConversationId::new("group:m6"),
            member: banned_member,
            reason: Some("spam".into()),
            decided_at_ms: 10_102,
        })
        .unwrap();
    let banned_send_error = engine
        .execute(Command::QueueMessage {
            conversation_id: ConversationId::new("group:m6"),
            local_message_id: MessageId::new("message:m6:banned"),
            client_message_id: ClientMessageId("client:m6:banned".into()),
            sender_id: ActorId::new("human:member"),
            content: text_message("blocked"),
            reply_to_message_id: None,
            thread_root_message_id: None,
            created_at_ms: 20_000,
            scheduled_at_ms: None,
            silent: false,
            protected_content: false,
        })
        .unwrap_err();
    assert!(matches!(
        banned_send_error,
        EngineError::CommunitySendRestricted(id) if id == ConversationId::new("group:m6")
    ));

    let final_community = &engine.state().communities[&ConversationId::new("group:m6")];
    assert!(final_community
        .admin_log
        .iter()
        .any(|entry| entry.action == CommunityAuditAction::SlowModeChanged));
    assert!(final_community
        .admin_log
        .iter()
        .any(|entry| entry.action == CommunityAuditAction::TopicUpserted));
    assert!(final_community
        .admin_log
        .iter()
        .any(|entry| entry.action == CommunityAuditAction::MemberChanged));
}

#[test]
fn respond_community_join_emits_participant_projection_only_when_approved() {
    let mut engine = MessagingEngine::new();
    for actor_id in [
        "human:owner",
        "human:admin",
        "human:approved",
        "human:rejected",
    ] {
        engine
            .execute(Command::UpsertActor {
                actor: Actor::human(actor_id, actor_id),
            })
            .unwrap();
    }
    engine
        .execute(Command::UpsertConversation {
            conversation: channel_conversation(),
        })
        .unwrap();
    engine
        .execute(Command::UpdateCommunity {
            actor_id: ActorId::new("human:owner"),
            community: channel_community(),
        })
        .unwrap();

    for (requester_id, requested_at_ms) in
        [("human:approved", 20_i64), ("human:rejected", 21_i64)]
    {
        engine
            .execute(Command::RequestCommunityJoin {
                actor_id: ActorId::new(requester_id),
                request: JoinRequest {
                    conversation_id: ConversationId::new("channel:m6"),
                    actor_id: ActorId::new(requester_id),
                    invite_link_id: None,
                    bio: None,
                    requested_at_ms,
                },
            })
            .unwrap();
    }

    let approved = engine
        .execute(Command::RespondCommunityJoin {
            actor_id: ActorId::new("human:owner"),
            conversation_id: ConversationId::new("channel:m6"),
            requester_id: ActorId::new("human:approved"),
            approved: true,
            decided_at_ms: 30,
        })
        .unwrap();
    assert_eq!(approved.len(), 2);
    assert!(matches!(&approved[0], Event::CommunityChanged { .. }));
    assert!(matches!(
        &approved[1],
        Event::ConversationParticipantUpserted {
            conversation_id,
            participant,
        } if conversation_id == &ConversationId::new("channel:m6")
            && participant.actor_id == ActorId::new("human:approved")
            && participant.role == ParticipantRole::Member
    ));

    let rejected = engine
        .execute(Command::RespondCommunityJoin {
            actor_id: ActorId::new("human:owner"),
            conversation_id: ConversationId::new("channel:m6"),
            requester_id: ActorId::new("human:rejected"),
            approved: false,
            decided_at_ms: 31,
        })
        .unwrap();
    assert_eq!(rejected.len(), 1);
    assert!(matches!(&rejected[0], Event::CommunityChanged { .. }));
}

#[test]
fn community_backed_create_is_idempotent_and_update_cannot_reown_or_retype() {
    let mut service = MessagingService::load(MemoryStateStore::default()).unwrap();
    for actor_id in ["human:owner", "human:admin", "human:attacker"] {
        service
            .handle(
                ClientEnvelope::new(
                    context(actor_id, &format!("profile:{actor_id}")),
                    ClientCommand::UpsertProfile {
                        actor: Actor::human(actor_id, actor_id),
                    },
                ),
                1,
            )
            .unwrap();
    }

    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "create-community-conversation"),
                ClientCommand::CreateConversation {
                    conversation: channel_conversation(),
                },
            ),
            2,
        )
        .unwrap();
    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "bind-community"),
                ClientCommand::UpdateCommunity {
                    community: channel_community(),
                },
            ),
            3,
        )
        .unwrap();

    let mut forged_create = Conversation::direct(
        "channel:m6",
        "forged create",
        vec![participant("human:attacker", ParticipantRole::Owner)],
        4,
    );
    forged_create.kind = ConversationKind::Direct;
    forged_create.owner_id = Some(ActorId::new("human:attacker"));
    let create_result = service
        .handle(
            ClientEnvelope::new(
                context("human:attacker", "forged-create"),
                ClientCommand::CreateConversation {
                    conversation: forged_create,
                },
            ),
            4,
        )
        .unwrap();
    assert!(create_result.is_empty());

    let after_create = &service.engine().state().conversations[&ConversationId::new("channel:m6")];
    assert_eq!(after_create.kind, ConversationKind::Channel);
    assert_eq!(after_create.owner_id, Some(ActorId::new("human:owner")));
    assert_eq!(after_create.participants.len(), 2);
    assert!(!after_create
        .participants
        .iter()
        .any(|participant| participant.actor_id == ActorId::new("human:attacker")));

    let mut forged_update = after_create.clone();
    forged_update.title = "safe metadata update".into();
    forged_update.kind = ConversationKind::Direct;
    forged_update.owner_id = Some(ActorId::new("human:attacker"));
    forged_update.participants = vec![participant("human:attacker", ParticipantRole::Owner)];
    service
        .handle(
            ClientEnvelope::new(
                context("human:owner", "forged-update"),
                ClientCommand::UpdateConversation {
                    conversation: forged_update,
                },
            ),
            5,
        )
        .unwrap();

    let after_update = &service.engine().state().conversations[&ConversationId::new("channel:m6")];
    assert_eq!(after_update.title, "safe metadata update");
    assert_eq!(after_update.kind, ConversationKind::Channel);
    assert_eq!(after_update.owner_id, Some(ActorId::new("human:owner")));
    assert_eq!(after_update.participants.len(), 2);
    assert!(!after_update
        .participants
        .iter()
        .any(|participant| participant.actor_id == ActorId::new("human:attacker")));

    let ordinary = Conversation::direct(
        "direct:p0-001",
        "ordinary",
        vec![participant("human:attacker", ParticipantRole::Owner)],
        6,
    );
    service
        .handle(
            ClientEnvelope::new(
                context("human:attacker", "ordinary-create"),
                ClientCommand::CreateConversation {
                    conversation: ordinary.clone(),
                },
            ),
            6,
        )
        .unwrap();
    assert_eq!(
        service
            .engine()
            .state()
            .conversations
            .get(&ConversationId::new("direct:p0-001")),
        Some(&ordinary)
    );
}

#[test]
fn request_join_without_community_remains_community_not_found() {
    let mut engine = MessagingEngine::new();
    for actor_id in ["human:owner", "human:requester"] {
        engine
            .execute(Command::UpsertActor {
                actor: Actor::human(actor_id, actor_id),
            })
            .unwrap();
    }
    let mut group = Conversation::direct(
        "group:no-community",
        "No Community",
        vec![participant("human:owner", ParticipantRole::Owner)],
        1,
    );
    group.kind = ConversationKind::Group;
    group.owner_id = Some(ActorId::new("human:owner"));
    engine
        .execute(Command::UpsertConversation { conversation: group })
        .unwrap();

    let error = engine
        .execute(Command::RequestCommunityJoin {
            actor_id: ActorId::new("human:requester"),
            request: JoinRequest {
                conversation_id: ConversationId::new("group:no-community"),
                actor_id: ActorId::new("human:requester"),
                invite_link_id: None,
                bio: None,
                requested_at_ms: 2,
            },
        })
        .unwrap_err();
    assert_eq!(
        error,
        EngineError::CommunityNotFound(ConversationId::new("group:no-community"))
    );
}
