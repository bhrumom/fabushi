use fabushi_messaging_core::*;

fn participant(actor_id: &str, role: ParticipantRole) -> Participant {
    Participant {
        actor_id: ActorId::new(actor_id),
        role,
        joined_at_ms: 1,
        muted_until_ms: None,
    }
}

#[test]
fn humans_and_bots_share_the_same_conversation_engine() {
    let mut engine = MessagingEngine::new();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::human("human:1", "善友"),
        })
        .unwrap();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::assistant("agent:mahayana", "大乘助手"),
        })
        .unwrap();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::bot("bot:publisher", "发布机器人"),
        })
        .unwrap();

    let conversation = Conversation::direct(
        "chat:unified",
        "善友 · 大乘助手 · 发布机器人",
        vec![
            participant("human:1", ParticipantRole::Owner),
            participant("agent:mahayana", ParticipantRole::Member),
            participant("bot:publisher", ParticipantRole::Member),
        ],
        10,
    );
    engine
        .execute(Command::UpsertConversation { conversation })
        .unwrap();
    let events = engine
        .execute(Command::QueueMessage {
            conversation_id: ConversationId::new("chat:unified"),
            local_message_id: MessageId::new("local:1"),
            client_message_id: ClientMessageId("client:1".into()),
            sender_id: ActorId::new("human:1"),
            content: MessageContent::Text {
                text: FormattedText::plain("请两个机器人协作处理"),
            },
            reply_to_message_id: None,
            thread_root_message_id: None,
            created_at_ms: 20,
            scheduled_at_ms: None,
            silent: false,
            protected_content: false,
        })
        .unwrap();
    assert!(matches!(events.as_slice(), [Event::MessageQueued { .. }]));
    assert_eq!(engine.state().actors.len(), 3);
    assert_eq!(
        engine.state().messages[&ConversationId::new("chat:unified")].len(),
        1
    );
}

#[test]
fn invoice_and_paid_order_use_the_same_chat_domain() {
    let mut engine = MessagingEngine::new();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::human("buyer", "购买者"),
        })
        .unwrap();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::bot("seller", "商店机器人"),
        })
        .unwrap();
    engine
        .execute(Command::UpsertConversation {
            conversation: Conversation::direct(
                "chat:shop",
                "商店",
                vec![
                    participant("buyer", ParticipantRole::Owner),
                    participant("seller", ParticipantRole::Member),
                ],
                1,
            ),
        })
        .unwrap();
    let invoice = Invoice {
        id: "invoice:1".into(),
        conversation_id: ConversationId::new("chat:shop"),
        seller_id: ActorId::new("seller"),
        title: "Mini App Pro".into(),
        description: "数字商品".into(),
        kind: InvoiceKind::DigitalGoods,
        currency: "USD".into(),
        prices: vec![PriceLine {
            label: "Pro".into(),
            amount: Money::new("USD", 999),
        }],
        payload: "product=pro".into(),
        provider_id: "fabushi-pay".into(),
        start_parameter: None,
        request_name: false,
        request_email: true,
        request_phone: false,
        request_shipping_address: false,
        flexible_shipping: false,
        created_at_ms: 2,
        expires_at_ms: None,
    };
    engine.execute(Command::CreateInvoice { invoice }).unwrap();
    engine
        .execute(Command::UpsertOrder {
            order: PaymentOrder {
                id: "order:1".into(),
                invoice_id: "invoice:1".into(),
                buyer_id: ActorId::new("buyer"),
                status: PaymentStatus::Pending,
                amount: Money::new("USD", 999),
                customer: None,
                provider_payment_id: None,
                provider_receipt_url: None,
                created_at_ms: 3,
                updated_at_ms: 3,
            },
        })
        .unwrap();
    engine.complete_paid_order("order:1", 4).unwrap();
    assert_eq!(engine.state().orders["order:1"].status, PaymentStatus::Paid);
}

#[test]
fn mini_app_permissions_are_enforced_before_host_calls() {
    let mut engine = MessagingEngine::new();
    engine
        .execute(Command::UpsertActor {
            actor: Actor::human("human:1", "善友"),
        })
        .unwrap();
    let manifest = MiniAppManifest {
        id: "mini:shop".into(),
        name: "商店".into(),
        version: "1.0.0".into(),
        description: "支付测试".into(),
        icon_url: None,
        start_url: "https://mini.example.invalid".into(),
        allowed_origins: vec!["https://mini.example.invalid".into()],
        requested_permissions: vec![MiniAppPermission::Payments],
        bot_actor_id: None,
        verified: true,
    };
    engine
        .execute(Command::InstallMiniApp { manifest })
        .unwrap();
    engine
        .execute(Command::GrantMiniApp {
            grant: MiniAppGrant {
                mini_app_id: "mini:shop".into(),
                actor_id: ActorId::new("human:1"),
                permissions: vec![MiniAppPermission::Payments],
                granted_at_ms: 1,
                expires_at_ms: None,
            },
        })
        .unwrap();
    engine
        .execute(Command::OpenMiniApp {
            session: MiniAppSession {
                id: "session:1".into(),
                mini_app_id: "mini:shop".into(),
                actor_id: ActorId::new("human:1"),
                conversation_id: None,
                start_parameter: None,
                granted_permissions: vec![MiniAppPermission::Payments],
                opened_at_ms: 2,
                expires_at_ms: 20,
            },
        })
        .unwrap();
    let error = engine
        .execute(Command::MiniAppCall {
            session_id: "session:1".into(),
            request_id: "request:1".into(),
            request: MiniAppRequest::RequestLocation,
        })
        .unwrap_err();
    assert_eq!(
        error,
        EngineError::MiniAppPermissionDenied(MiniAppPermission::Location)
    );
}

#[test]
fn wire_protocol_is_fabushi_owned_and_versioned() {
    let envelope = ClientEnvelope::new(
        RequestContext {
            request_id: "req:1".into(),
            device_id: "desktop:1".into(),
            actor_id: ActorId::new("human:1"),
            session_id: "session:1".into(),
            sent_at_ms: 10,
        },
        ClientCommand::Sync {
            cursor: None,
            limit: 100,
        },
    );
    let json = serde_json::to_string(&envelope).unwrap();
    assert!(json.contains("protocolVersion"));
    assert!(!json.to_ascii_lowercase().contains("mtproto"));
    assert_eq!(
        envelope.protocol_version,
        FABUSHI_MESSAGING_PROTOCOL_VERSION
    );
}
