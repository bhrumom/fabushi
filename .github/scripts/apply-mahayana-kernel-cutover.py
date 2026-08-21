from pathlib import Path

path = Path("third_party/mahayana/mahayana-rs/mahayana-runtime/src/lib.rs")
text = path.read_text()

replacements = [
    (
        "//! Long-lived local conversation runtime used by all Mahayana frontends.\n\n",
        "//! Long-lived local conversation runtime used by all Mahayana frontends.\n\nmod kernel_conversation;\n\n",
    ),
    (
        "use mahayana_agent::StartThreadRequest;\n",
        "use mahayana_agent::StartThreadRequest;\nuse mahayana_agent_kernel_bridge::LegacyAgentKernelBridge;\n",
    ),
    (
        "use mahayana_conversation::SharedConversationEventSink;\n",
        "use mahayana_conversation::SharedConversationEventSink;\nuse kernel_conversation::KernelConversationProvider;\n",
    ),
    (
        "use mahayana_core::capability::CapabilityRegistry;\n",
        "use mahayana_core::capability::CapabilityRegistry;\nuse mahayana_kernel::BackendDescriptor;\nuse mahayana_kernel::Capability;\nuse mahayana_kernel::CapabilitySet;\nuse mahayana_kernel::EngineBackend;\n",
    ),
    (
        '''        self.providers\n            .register(Arc::new(AgentConversationProvider::new(Arc::clone(\n                &backend,\n            ))))?;\n        self.agent_backend = Some(backend);\n''',
        '''        let kernel_backend: Arc<dyn EngineBackend> = Arc::new(LegacyAgentKernelBridge::new(\n            Arc::clone(&backend),\n            legacy_backend_descriptor(backend.as_ref()),\n        ));\n        self.providers.register(Arc::new(KernelConversationProvider::new(\n            kernel_backend,\n            self.config.build_profile,\n        )))?;\n        self.agent_backend = Some(backend);\n''',
    ),
    (
        "fn create_async_runtime() -> Result<tokio::runtime::Runtime, RuntimeError> {\n",
        '''fn legacy_backend_descriptor(backend: &dyn AgentBackend) -> BackendDescriptor {\n    BackendDescriptor {\n        id: format!("compat:{}", backend.name()),\n        display_name: format!("{} compatibility backend", backend.name()),\n        native: false,\n        capabilities: CapabilitySet::new([\n            Capability::Model,\n            Capability::FilesystemRead,\n            Capability::FilesystemWrite,\n            Capability::Process,\n            Capability::Git,\n            Capability::Network,\n            Capability::WebSearch,\n            Capability::ComputerUse,\n            Capability::ToolProtocol,\n            Capability::Mcp,\n            Capability::Skills,\n            Capability::Plugins,\n        ]),\n    }\n}\n\nfn create_async_runtime() -> Result<tokio::runtime::Runtime, RuntimeError> {\n''',
    ),
]

for old, new in replacements:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"guard failed: expected exactly one match, found {count}: {old[:100]!r}")
    text = text.replace(old, new, 1)

path.write_text(text)
print("Mahayana runtime conversation path now routes through the sovereign kernel")
