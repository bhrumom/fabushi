from pathlib import Path


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    count = text.count(old)
    if count != 1:
        if new in text:
            return
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:120]!r}")
    path.write_text(text.replace(old, new, 1))


kernel_provider = Path("third_party/mahayana/mahayana-rs/mahayana-runtime/src/kernel_conversation.rs")
replace_once(
    kernel_provider,
    '''pub struct KernelConversationProvider {
    backend: Arc<dyn EngineBackend>,
    profile: BuildProfile,
    session_id: AsyncMutex<Option<SessionId>>,
    history: Arc<Mutex<Vec<Message>>>,
}

impl KernelConversationProvider {
    pub fn new(backend: Arc<dyn EngineBackend>, profile: BuildProfile) -> Self {
        Self {
            backend,
            profile,
            session_id: AsyncMutex::new(None),
            history: Arc::new(Mutex::new(Vec::new())),
        }
    }
''',
    '''pub struct KernelConversationProvider {
    backend: Arc<dyn EngineBackend>,
    profile: BuildProfile,
    workspace_root: Option<String>,
    model: Option<String>,
    session_id: AsyncMutex<Option<SessionId>>,
    history: Arc<Mutex<Vec<Message>>>,
}

impl KernelConversationProvider {
    pub fn new(
        backend: Arc<dyn EngineBackend>,
        profile: BuildProfile,
        workspace_root: Option<String>,
        model: Option<String>,
    ) -> Self {
        Self {
            backend,
            profile,
            workspace_root,
            model,
            session_id: AsyncMutex::new(None),
            history: Arc::new(Mutex::new(Vec::new())),
        }
    }
''',
)
replace_once(
    kernel_provider,
    '''                profile: runtime_profile(self.profile),
                workspace_root: None,
                model: None,
                metadata: json!({"conversationId": conversation_id.as_str()}),
''',
    '''                profile: runtime_profile(self.profile),
                workspace_root: self.workspace_root.clone(),
                model: self.model.clone(),
                metadata: json!({"conversationId": conversation_id.as_str()}),
''',
)

runtime = Path("third_party/mahayana/mahayana-rs/mahayana-runtime/src/lib.rs")
replace_once(
    runtime,
    '''    pub fn with_agent_backend(
        mut self,
        backend: Arc<dyn AgentBackend>,
    ) -> Result<Self, RuntimeError> {
        let kernel_backend: Arc<dyn EngineBackend> = Arc::new(LegacyAgentKernelBridge::new(
            Arc::clone(&backend),
            legacy_backend_descriptor(backend.as_ref()),
        ));
        self.providers
            .register(Arc::new(KernelConversationProvider::new(
                kernel_backend,
                self.config.build_profile,
            )))?;
        self.agent_backend = Some(backend);
        Ok(self)
    }
''',
    '''    pub fn with_engine_backend(
        mut self,
        backend: Arc<dyn EngineBackend>,
    ) -> Result<Self, RuntimeError> {
        let workspace_root = self
            .config
            .workspace_roots
            .first()
            .map(|path| path.to_string_lossy().to_string());
        let model = Some(self.config.model.model.clone());
        self.providers
            .register(Arc::new(KernelConversationProvider::new(
                backend,
                self.config.build_profile,
                workspace_root,
                model,
            )))?;
        Ok(self)
    }

    pub fn with_agent_control_backend(mut self, backend: Arc<dyn AgentBackend>) -> Self {
        self.agent_backend = Some(backend);
        self
    }

    pub fn with_agent_backend(
        self,
        backend: Arc<dyn AgentBackend>,
    ) -> Result<Self, RuntimeError> {
        let kernel_backend: Arc<dyn EngineBackend> = Arc::new(LegacyAgentKernelBridge::new(
            Arc::clone(&backend),
            legacy_backend_descriptor(backend.as_ref()),
        ));
        Ok(self
            .with_engine_backend(kernel_backend)?
            .with_agent_control_backend(backend))
    }
''',
)

host_cargo = Path("third_party/mahayana/mahayana-rs/mahayana-host/Cargo.toml")
host_cargo.write_text('''[package]
name = "mahayana-host"
version.workspace = true
edition.workspace = true
license.workspace = true
description = "Direct Rust host API for native Mahayana application shells."
publish = false

[lib]
doctest = false

[features]
default = ["local-only"]
desktop-full = ["mahayana-runtime-core/desktop-full"]
mobile-embedded = ["mahayana-runtime-core/mobile-embedded"]
linux-shared = ["desktop-full"]
web-wasm = ["mahayana-runtime-core/web-wasm"]
local-only = ["mahayana-runtime-core/local-only"]
remote-model-provider = ["mahayana-runtime-core/remote-model-provider"]
telemetry = ["mahayana-runtime-core/telemetry"]
codex-compat = ["dep:mahayana-agent-codex", "dep:codex-protocol"]

[dependencies]
async-trait.workspace = true
codex-protocol = { workspace = true, optional = true }
fabushi-official-miniapps.workspace = true
mahayana-agent.workspace = true
mahayana-agent-codex = { path = "../mahayana-agent-codex", optional = true }
mahayana-conversation.workspace = true
mahayana-core.workspace = true
mahayana-kernel.workspace = true
mahayana-mcp-runtime.workspace = true
mahayana-miniapp.workspace = true
mahayana-model.workspace = true
mahayana-native-agent.workspace = true
mahayana-native-engine.workspace = true
mahayana-platform-core.workspace = true
mahayana-product.workspace = true
mahayana-runtime-core = { package = "mahayana-runtime", path = "../mahayana-runtime", default-features = false }
mahayana-social.workspace = true
mahayana-telegram.workspace = true
serde.workspace = true
serde_json.workspace = true
thiserror.workspace = true
''')

host = Path("third_party/mahayana/mahayana-rs/mahayana-host/src/lib.rs")
text = host.read_text()
text = text.replace(
    '''use mahayana_agent::UnavailableAgentBackend;
#[cfg(any(feature = "desktop-full", feature = "mobile-embedded"))]
use mahayana_agent_codex::CodexAgentBackend;
#[cfg(any(feature = "desktop-full", feature = "mobile-embedded"))]
use mahayana_agent_codex::CodexAgentConfig;
#[cfg(any(feature = "desktop-full", feature = "mobile-embedded"))]
use mahayana_conversation::ConversationProvider;
''',
    '''use mahayana_agent::UnavailableAgentBackend;
#[cfg(feature = "codex-compat")]
use mahayana_agent_codex::CodexAgentBackend;
#[cfg(feature = "codex-compat")]
use mahayana_agent_codex::CodexAgentConfig;
#[cfg(feature = "codex-compat")]
use mahayana_conversation::ConversationProvider;
''',
)
insert_after = 'use mahayana_miniapp::MiniAppDefinition;\n'
if 'use mahayana_native_engine::NativeEngine;' not in text:
    text = text.replace(
        insert_after,
        insert_after
        + 'use mahayana_kernel::EngineBackend;\n'
        + 'use mahayana_mcp_runtime::NativeMcpRegistry;\n'
        + 'use mahayana_model::ResponsesModelConfig;\n'
        + 'use mahayana_model::ResponsesModelRuntime;\n'
        + 'use mahayana_native_agent::NativeAgentBackend;\n'
        + 'use mahayana_native_agent::NativeAgentConfig;\n'
        + 'use mahayana_native_engine::NativeEngine;\n'
        + 'use mahayana_native_engine::NativeEngineConfig;\n',
    )

start = text.index('fn build_runtime(\n')
end = text.index('\nfn merge_installed_mini_apps(', start)
new_build = r'''fn build_runtime(
    create: HostCreateConfig,
    product_client: MahayanaProductClient,
) -> Result<MahayanaRuntime, HostError> {
    let mut runtime_config = create.runtime.clone();
    if runtime_config.remote_agent_enabled {
        return Err(RuntimeError::RemoteAgentForbidden.into());
    }
    #[cfg(all(feature = "mobile-embedded", not(feature = "desktop-full")))]
    {
        runtime_config.build_profile = BuildProfile::MobileEmbedded;
    }
    let host_platform = create
        .host_platform
        .unwrap_or(match runtime_config.build_profile {
            BuildProfile::DesktopFull => HostPlatform::Desktop,
            BuildProfile::MobileEmbedded => HostPlatform::Mobile,
            BuildProfile::WebWasm => HostPlatform::Web,
        });
    let inherit_installed_plugins = create.inherit_installed_plugins.unwrap_or(
        matches!(runtime_config.build_profile, BuildProfile::DesktopFull) && !cfg!(test),
    );
    let configured_mini_apps = merge_installed_mini_apps(
        create.mini_apps.clone(),
        create.cwd.as_deref(),
        inherit_installed_plugins,
    );
    let mini_apps = merge_official_mini_apps(configured_mini_apps);
    let session_token = product_client.session_token().ok();

    let data_dir = runtime_config.data_dir.clone();
    let cwd = create
        .cwd
        .clone()
        .or_else(|| runtime_config.workspace_roots.first().cloned())
        .or_else(|| data_dir.as_ref().map(|path| path.join("workspace")))
        .or_else(|| std::env::current_dir().ok());
    if runtime_config.workspace_roots.is_empty() {
        if let Some(cwd) = cwd.as_ref() {
            runtime_config.workspace_roots.push(cwd.clone());
        }
    }

    let mut builder = RuntimeBuilder::new(runtime_config.clone());
    #[cfg(feature = "codex-compat")]
    let mut compatibility_conversation_providers: Vec<Arc<dyn ConversationProvider>> = Vec::new();
    if let Some(token) = session_token.as_ref() {
        let provider = Arc::new(MahayanaSocialConversationProvider::new(
            product_client.clone(),
            Some(token.clone()),
        ));
        #[cfg(feature = "codex-compat")]
        compatibility_conversation_providers
            .push(Arc::clone(&provider) as Arc<dyn ConversationProvider>);
        builder = builder.with_provider(provider)?;
    }
    if let Some(telegram_client_id) = create.telegram_client_id {
        let provider = Arc::new(TelegramConversationProvider::from_client_id(
            telegram_client_id,
            create.telegram_self_user_id.unwrap_or_default(),
        ));
        #[cfg(feature = "codex-compat")]
        compatibility_conversation_providers
            .push(Arc::clone(&provider) as Arc<dyn ConversationProvider>);
        builder = builder.with_provider(provider)?;
    }

    #[cfg(feature = "codex-compat")]
    if std::env::var("MAHAYANA_AGENT_ENGINE").ok().as_deref() == Some("codex")
        && matches!(
            runtime_config.build_profile,
            BuildProfile::DesktopFull | BuildProfile::MobileEmbedded
        )
    {
        let cwd = cwd.clone().ok_or_else(|| HostError::new("current working directory is unavailable"))?;
        let codex_home = create
            .codex_home
            .clone()
            .or_else(|| data_dir.clone().map(|path| path.join("codex")))
            .or_else(default_codex_home_if_available)
            .ok_or_else(|| HostError::new("Codex compatibility mode requires an application data directory"))?;
        let responses_base_url = runtime_config
            .model
            .base_url
            .clone()
            .ok_or_else(|| HostError::new("Mahayana Responses base URL is required"))?;
        let settings = CodexAgentConfig {
            codex_home,
            inherit_installed_plugins,
            cwd,
            workspace_roots: runtime_config.workspace_roots.clone(),
            model: runtime_config.model.model.clone(),
            responses_base_url,
            use_codex_account: create.use_codex_account,
            product_session_token: session_token.clone(),
            sandbox_mode: codex_protocol::config_types::SandboxMode::WorkspaceWrite,
            approval_policy: codex_protocol::protocol::AskForApproval::OnRequest,
            codex_executable_path: create.codex_executable_path.clone(),
            conversation_providers: compatibility_conversation_providers,
        };
        return builder
            .build_with_agent_backend_and(
                || async move {
                    let backend = CodexAgentBackend::start(settings).await?;
                    Ok(Arc::new(backend) as Arc<dyn mahayana_agent::AgentBackend>)
                },
                move |builder, backend| {
                    let provider = MiniAppConversationProvider::new_for_platform_with_entitlements(
                        backend,
                        mini_apps,
                        host_platform,
                        Some(Arc::new(PlatformEntitlementChecker {
                            client: product_client,
                        })),
                    )?;
                    builder.with_provider(Arc::new(provider))
                },
            )
            .map_err(HostError::from);
    }

    #[cfg(any(feature = "desktop-full", feature = "mobile-embedded"))]
    if matches!(
        runtime_config.build_profile,
        BuildProfile::DesktopFull | BuildProfile::MobileEmbedded
    ) {
        let cwd = cwd.ok_or_else(|| HostError::new("current working directory is unavailable"))?;
        let base_url = runtime_config
            .model
            .base_url
            .clone()
            .ok_or_else(|| HostError::new("Mahayana model base URL is required"))?;
        let model_runtime = Arc::new(
            ResponsesModelRuntime::new(ResponsesModelConfig {
                base_url,
                default_model: runtime_config.model.model.clone(),
                bearer_token: session_token.clone(),
                provider_mode: runtime_config.model.provider,
            })
            .map_err(|error| HostError::new(error.to_string()))?,
        );
        let engine_config = match runtime_config.build_profile {
            BuildProfile::DesktopFull => NativeEngineConfig::desktop(runtime_config.model.model.clone()),
            BuildProfile::MobileEmbedded | BuildProfile::WebWasm => {
                NativeEngineConfig::embedded(runtime_config.model.model.clone())
            }
        };
        let native_engine = Arc::new(
            NativeEngine::new(model_runtime, engine_config)
                .map_err(|error| HostError::new(error.to_string()))?,
        );
        let engine_backend: Arc<dyn EngineBackend> = native_engine.clone();
        let mcp_roots = runtime_config
            .workspace_roots
            .iter()
            .map(|root| root.join(".agents/plugins/plugins"))
            .collect::<Vec<_>>();
        let mcp_registry = NativeMcpRegistry::new(mcp_roots, session_token.clone());
        let native_agent: Arc<dyn mahayana_agent::AgentBackend> = Arc::new(
            NativeAgentBackend::new(
                native_engine,
                NativeAgentConfig {
                    profile: match runtime_config.build_profile {
                        BuildProfile::DesktopFull => mahayana_kernel::RuntimeProfile::DesktopFull,
                        BuildProfile::MobileEmbedded => mahayana_kernel::RuntimeProfile::MobileEmbedded,
                        BuildProfile::WebWasm => mahayana_kernel::RuntimeProfile::WebWasm,
                    },
                    workspace_root: Some(cwd),
                    mcp_registry,
                },
            ),
        );
        let miniapp = MiniAppConversationProvider::new_for_platform_with_entitlements(
            Arc::clone(&native_agent),
            mini_apps,
            host_platform,
            Some(Arc::new(PlatformEntitlementChecker {
                client: product_client,
            })),
        )
        .map_err(|error| HostError::new(error.to_string()))?;
        return builder
            .with_engine_backend(engine_backend)?
            .with_agent_control_backend(native_agent)
            .with_provider(Arc::new(miniapp))?
            .build()
            .map_err(HostError::from);
    }

    let unavailable_reason = "this platform build has no native Mahayana Agent backend";
    let backend: Arc<dyn mahayana_agent::AgentBackend> =
        Arc::new(UnavailableAgentBackend::new(unavailable_reason));
    let miniapp = MiniAppConversationProvider::new_for_platform_with_entitlements(
        Arc::clone(&backend),
        mini_apps,
        host_platform,
        Some(Arc::new(PlatformEntitlementChecker {
            client: product_client,
        })),
    )
    .map_err(|error| HostError::new(error.to_string()))?;
    builder
        .with_agent_backend(backend)?
        .with_provider(Arc::new(miniapp))?
        .build()
        .map_err(HostError::from)
}
'''
text = text[:start] + new_build + text[end:]
text = text.replace('#[cfg(feature = "desktop-full")]\nfn default_codex_home()', '#[cfg(all(feature = "codex-compat", feature = "desktop-full"))]\nfn default_codex_home()')
text = text.replace('#[cfg(any(feature = "desktop-full", feature = "mobile-embedded"))]\nfn default_codex_home_if_available()', '#[cfg(feature = "codex-compat")]\nfn default_codex_home_if_available()')
host.write_text(text)

miniapp = Path("third_party/mahayana/mahayana-rs/mahayana-miniapp/src/lib.rs")
text = miniapp.read_text()
text = text.replace("准备把当前小程序问题交给 Codex 修复。", "准备把当前小程序问题交给 Mahayana 修复。")
text = text.replace("当前 Codex 工作区工具", "当前 Mahayana 工作区工具")
text = text.replace("Codex 插件工作台", "Mahayana 插件工作台")
miniapp.write_text(text)

print("Cut Mahayana production Host over to the sovereign native engine and MCP runtime")
