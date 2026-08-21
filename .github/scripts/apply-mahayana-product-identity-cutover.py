from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:100]!r}")
    path.write_text(text.replace(old, new, 1))


core = Path("third_party/mahayana/mahayana-rs/mahayana-core/src/lib.rs")
replace_once(
    core,
    'pub const CODEX_ASSISTANT_CONVERSATION_ID: &str = "codex:agent:assistant";\n',
    'pub const MAHAYANA_AI_CONVERSATION_ID: &str = "mahayana-ai:agent:assistant";\n'
    '/// Legacy source-compatible alias. New product surfaces must use `MAHAYANA_AI_CONVERSATION_ID`.\n'
    'pub const CODEX_ASSISTANT_CONVERSATION_ID: &str = MAHAYANA_AI_CONVERSATION_ID;\n',
)
replace_once(
    core,
    'pub enum PeerKind {\n    CodexAi,\n',
    'pub enum PeerKind {\n    MahayanaAi,\n    /// Read compatibility for persisted pre-sovereign conversation payloads.\n    CodexAi,\n',
)
replace_once(
    core,
    '            Self::CodexAi => "codex",\n',
    '            Self::MahayanaAi | Self::CodexAi => "mahayana-ai",\n',
)
replace_once(
    core,
    '''impl Conversation {\n    pub fn codex_assistant() -> Self {\n        Self {\n            id: ConversationId(CODEX_ASSISTANT_CONVERSATION_ID.to_string()),\n            title: "Mahayana（大乘 AI）".to_string(),\n            peer: PeerKind::CodexAi,\n            pinned: true,\n            unread_count: 0,\n            updated_at_ms: 0,\n        }\n    }\n}\n''',
    '''impl Conversation {\n    pub fn mahayana_assistant() -> Self {\n        Self {\n            id: ConversationId(MAHAYANA_AI_CONVERSATION_ID.to_string()),\n            title: "Mahayana（大乘 AI）".to_string(),\n            peer: PeerKind::MahayanaAi,\n            pinned: true,\n            unread_count: 0,\n            updated_at_ms: 0,\n        }\n    }\n\n    /// Source-compatible helper for callers not yet migrated. It intentionally\n    /// returns the sovereign Mahayana conversation, never a new Codex identity.\n    pub fn codex_assistant() -> Self {\n        Self::mahayana_assistant()\n    }\n}\n''',
)
replace_once(
    core,
    "/// Provider-reported model token counts. These values are projected from the\n/// Codex Responses usage event and are never estimated by the Mahayana host.\n",
    "/// Provider-reported model token counts. These values come from the selected\n/// Mahayana model backend and are never estimated by the product host.\n",
)

capability = Path("third_party/mahayana/mahayana-rs/mahayana-core/src/capability.rs")
replace_once(
    capability,
    '        PeerKind::CodexAi => (\n',
    '        PeerKind::MahayanaAi | PeerKind::CodexAi => (\n',
)

kernel_provider = Path(
    "third_party/mahayana/mahayana-rs/mahayana-runtime/src/kernel_conversation.rs"
)
replace_once(
    kernel_provider,
    '        let mut conversation = Conversation::codex_assistant();\n        conversation.id = ConversationId(MAHAYANA_AI_CONVERSATION_ID.to_string());\n        Ok(vec![conversation])\n',
    '        Ok(vec![Conversation::mahayana_assistant()])\n',
)

for relative in [
    "frontend/apps/web/src/app/host/host-client.tsx",
    "frontend/apps/web/src/lib/mahayana-host/mock-transport.ts",
    "scripts/test-mahayana-wasm.mjs",
]:
    path = Path(relative)
    text = path.read_text()
    if "codex:agent:assistant" in text:
        path.write_text(text.replace("codex:agent:assistant", "mahayana-ai:agent:assistant"))

print("Mahayana AI identity is now canonical; legacy Codex IDs remain read-compatible only")
