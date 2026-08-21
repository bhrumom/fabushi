use fabushi_messaging_core::*;
use std::collections::BTreeMap;

fn context(actor_id: &str) -> RequestContext {
    RequestContext {
        request_id: "request:1".into(),
        device_id: "desktop:1".into(),
        actor_id: ActorId::new(actor_id),
        session_id: "session:1".into(),
        sent_at_ms: 10,
    }
}

#[test]
fn self_hosted_service_persists_and_restores_state() {
    let store = MemoryStateStore::default();
    let mut service = MessagingService::load(store).unwrap();

    service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::UpsertProfile {
                    actor: Actor::human("human:1", "善友"),
                },
            ),
            10,
        )
        .unwrap();

    service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::CreateConversation {
                    conversation: Conversation::direct(
                        "chat:1",
                        "自建会话",
                        vec![Participant {
                            actor_id: ActorId::new("human:1"),
                            role: ParticipantRole::Owner,
                            joined_at_ms: 10,
                            muted_until_ms: None,
                        }],
                        10,
                    ),
                },
            ),
            11,
        )
        .unwrap();

    service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::SendMessage {
                    conversation_id: ConversationId::new("chat:1"),
                    client_message_id: ClientMessageId("client:1".into()),
                    content: MessageContent::Text {
                        text: FormattedText::plain("完全自建消息"),
                    },
                    reply_to_message_id: None,
                    thread_root_message_id: None,
                    scheduled_at_ms: None,
                    silent: false,
                    protected_content: false,
                },
            ),
            12,
        )
        .unwrap();

    let cursor = service.cursor();
    assert!(cursor >= 3);
    let store = service.into_store();
    let restored = MessagingService::load(store).unwrap();
    assert_eq!(restored.cursor(), cursor);
    assert_eq!(restored.engine().state().actors.len(), 1);
    assert_eq!(restored.engine().state().conversations.len(), 1);
    assert_eq!(
        restored.engine().state().messages[&ConversationId::new("chat:1")].len(),
        1
    );
}

#[test]
fn sync_uses_the_fabushi_protocol_cursor() {
    let mut service = MessagingService::load(MemoryStateStore::default()).unwrap();
    let events = service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::Sync {
                    cursor: None,
                    limit: 100,
                },
            ),
            20,
        )
        .unwrap();
    assert_eq!(events.len(), 1);
    assert_eq!(
        events[0].protocol_version,
        FABUSHI_MESSAGING_PROTOCOL_VERSION
    );
    assert!(matches!(events[0].event, ServerEvent::SyncBatch { .. }));
}

#[test]
fn realtime_state_tracks_group_call_media_and_typing() {
    let call_id = CallId("call:1".into());
    let actor_id = ActorId::new("human:1");
    let mut participants = BTreeMap::new();
    participants.insert(
        actor_id.clone(),
        CallParticipant {
            actor_id: actor_id.clone(),
            joined_at_ms: Some(1),
            left_at_ms: None,
            muted: false,
            video_enabled: true,
            screen_sharing: false,
            speaking: false,
        },
    );
    let mut realtime = RealtimeState::default();
    realtime
        .create_call(CallSession {
            id: call_id.clone(),
            conversation_id: ConversationId::new("group:1"),
            kind: CallKind::GroupVideo,
            state: CallState::Active,
            initiator_id: actor_id.clone(),
            participants,
            route: Some(CallRoute {
                region: "auto".into(),
                signaling_url: "wss://realtime.fabushi.invalid".into(),
                media_relay_urls: vec!["turns://relay.fabushi.invalid".into()],
                ice_servers: Vec::new(),
                end_to_end_encrypted: true,
            }),
            created_at_ms: 1,
            connected_at_ms: Some(2),
            ended_at_ms: None,
        })
        .unwrap();
    realtime
        .set_participant_media(&call_id, &actor_id, true, false, true)
        .unwrap();
    let participant = &realtime.calls[&call_id].participants[&actor_id];
    assert!(participant.muted);
    assert!(!participant.video_enabled);
    assert!(participant.screen_sharing);

    realtime.set_typing(TypingState {
        conversation_id: ConversationId::new("group:1"),
        actor_id,
        action: "typing".into(),
        expires_at_ms: 50,
    });
    realtime.expire_typing(51);
    assert!(realtime.typing.is_empty());
}

#[test]
fn messaging_service_streams_blob_chunks_to_self_hosted_storage() {
    let root = std::env::temp_dir().join(format!(
        "fabushi-messaging-blob-contract-{}-{}",
        std::process::id(),
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    ));
    let blob_root = root.join("blobs");
    let store = MemoryStateStore::default();
    let mut service =
        MessagingService::load_with_blob_store(store, FileBlobStore::new(&blob_root)).unwrap();
    let id = BlobId::new("blob-contract-1").unwrap();
    let metadata = BlobMetadata {
        id: id.clone(),
        file_name: "hello.txt".into(),
        mime_type: "text/plain".into(),
        size_bytes: 5,
        content_hash: None,
        created_at_ms: 10,
    };
    service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::BeginBlobUpload {
                    metadata: metadata.clone(),
                },
            ),
            10,
        )
        .unwrap();
    service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::AppendBlobChunk {
                    blob_id: id.clone(),
                    offset: 0,
                    data_base64: "aGVsbG8=".into(),
                },
            ),
            11,
        )
        .unwrap();
    let events = service
        .handle(
            ClientEnvelope::new(
                context("human:1"),
                ClientCommand::FinishBlobUpload {
                    blob_id: id.clone(),
                },
            ),
            12,
        )
        .unwrap();
    assert!(matches!(events[0].event, ServerEvent::BlobReady { .. }));
    assert_eq!(
        FileBlobStore::new(&blob_root)
            .read_range(&id, 0, 5)
            .unwrap(),
        b"hello"
    );
    let _ = std::fs::remove_dir_all(root);
}
