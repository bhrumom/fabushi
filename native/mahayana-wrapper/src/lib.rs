//! Product-named compatibility surface. Existing mobile callers may continue
//! using `codex-wrapper` until their ABI migration, while new integrations use
//! this crate and do not depend on Codex product naming.

mod kernel;

pub use codex_wrapper::{CodexClient as MahayanaClient, CodexConfig as MahayanaConfig};
pub use codex_wrapper::{
    CodexEvent as MahayanaEvent, CodexModelConfig as MahayanaModelConfig,
    CodexModelGateway as MahayanaModelGateway, CodexTransport as MahayanaTransport,
    ModelProviderType, ToolDefinition, VirtualFile, VirtualVfs,
    WorkspaceThread as MahayanaWorkspaceThread,
};
pub use kernel::{MahayanaKernel, MahayanaKernelError, MiniAppInspection};

/// Forces the legacy Flutter ABI entry points into the unified dynamic library.
/// Existing Dart services can therefore load `mahayana-wrapper` first without
/// changing their Telegram or mini-app request contracts.
#[no_mangle]
pub extern "C" fn mahayana_force_link() -> u32 {
    let telegram_symbols = [
        fabushi_telegram_runtime::fabushi_telegram_create_client as *const () as usize,
        fabushi_telegram_runtime::fabushi_telegram_create_persistent_client as *const () as usize,
        fabushi_telegram_runtime::fabushi_telegram_execute as *const () as usize,
        fabushi_telegram_runtime::fabushi_telegram_close_client as *const () as usize,
        fabushi_telegram_runtime::fabushi_telegram_free_string as *const () as usize,
        fabushi_telegram_runtime::fabushi_telegram_force_link as *const () as usize,
    ];
    let miniapp_symbols = [
        fabushi_miniapp_runtime::fabushi_runtime_create_client as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_send as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_receive as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_execute as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_close as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_close_client as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_free_string as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_http_fetch_json as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_udp_open_json as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_udp_send_json as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_udp_broadcast_json as *const () as usize,
        fabushi_miniapp_runtime::fabushi_runtime_udp_close_json as *const () as usize,
    ];
    std::hint::black_box((telegram_symbols, miniapp_symbols));
    1
}

/// The bundled Global Dharma MCP server name consumed by the Mahayana fork.
pub const GLOBAL_DHARMA_MCP_SERVER: &str = "global-dharma";
/// The TUI mention used to select the Global Dharma capability group.
pub const GLOBAL_DHARMA_MENTION: &str = "@global-dharma";

#[cfg(test)]
mod tests {
    #[test]
    fn unified_library_keeps_legacy_ffi_symbols_linked() {
        assert_eq!(super::mahayana_force_link(), 1);
    }
}
