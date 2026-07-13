//! Product-named compatibility surface. Existing mobile callers may continue
//! using `codex-wrapper` until their ABI migration, while new integrations use
//! this crate and do not depend on Codex product naming.

mod kernel;
mod product;

use std::{
    ffi::{CStr, CString},
    os::raw::c_char,
    panic::{catch_unwind, AssertUnwindSafe},
};

use serde_json::{json, Value};

pub use codex_wrapper::{CodexClient as MahayanaClient, CodexConfig as MahayanaConfig};
pub use codex_wrapper::{
    CodexEvent as MahayanaEvent, CodexModelConfig as MahayanaModelConfig,
    CodexModelGateway as MahayanaModelGateway, CodexTransport as MahayanaTransport,
    ModelProviderType, ToolDefinition, VirtualFile, VirtualVfs,
    WorkspaceThread as MahayanaWorkspaceThread,
};
pub use kernel::{MahayanaKernel, MahayanaKernelError, MiniAppInspection};
pub use product::{redact_secrets, MahayanaProductClient, ProductError};

/// Runs an agent turn through the Codex Rust SDK. The request must be a JSON
/// object containing a non-empty `prompt`; optional SDK fields are documented
/// by `MahayanaKernel::run_codex_blocking`. The returned string is owned by
/// Rust and must be released with [`mahayana_free_string`].
///
/// # Safety
/// `request_json` must point to a valid NUL-terminated UTF-8 JSON object for
/// the duration of this call. Release the returned pointer exactly once with
/// [`mahayana_free_string`].
#[no_mangle]
pub unsafe extern "C" fn mahayana_codex_run(request_json: *const c_char) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        let request = parse_ffi_request(request_json)?;
        MahayanaKernel::default()
            .run_codex_blocking(&request)
            .map_err(|error| error.to_string())
    }));
    let response = match result {
        Ok(Ok(data)) => json!({"ok": true, "data": data}),
        Ok(Err(message)) => json!({
            "ok": false,
            "errorCode": "mahayana_codex_sdk_error",
            "message": message,
        }),
        Err(_) => json!({
            "ok": false,
            "errorCode": "mahayana_codex_sdk_panic",
            "message": "Mahayana Codex Rust SDK panicked while processing the request.",
        }),
    };
    into_owned_c_string(response)
}

/// Executes any Mahayana product command through the shared Rust kernel. This
/// is the preferred native App/Desktop ABI for auth, contacts, messages,
/// mini-apps, Telegram, and Codex turns.
///
/// # Safety
/// `request_json` must point to a valid NUL-terminated UTF-8 JSON object for
/// the duration of this call. Release the returned pointer with
/// [`mahayana_free_string`].
#[no_mangle]
pub unsafe extern "C" fn mahayana_execute(request_json: *const c_char) -> *mut c_char {
    let result = catch_unwind(AssertUnwindSafe(|| {
        let request = parse_ffi_request(request_json)?;
        MahayanaKernel::default()
            .execute(request)
            .map_err(|error| error.to_string())
    }));
    let response = match result {
        Ok(Ok(data)) => json!({"ok": true, "data": data}),
        Ok(Err(message)) => json!({
            "ok": false,
            "errorCode": "mahayana_kernel_error",
            "message": message,
        }),
        Err(_) => json!({
            "ok": false,
            "errorCode": "mahayana_kernel_panic",
            "message": "Mahayana Rust kernel panicked while processing the request.",
        }),
    };
    into_owned_c_string(response)
}

unsafe fn parse_ffi_request(request_json: *const c_char) -> Result<Value, String> {
    if request_json.is_null() {
        return Err("request_json must not be null".to_string());
    }
    let source = CStr::from_ptr(request_json)
        .to_str()
        .map_err(|error| format!("request_json must be UTF-8: {error}"))?;
    let request: Value = serde_json::from_str(source)
        .map_err(|error| format!("request_json must be a JSON object: {error}"))?;
    if !request.is_object() {
        return Err("request_json must be a JSON object".to_string());
    }
    Ok(request)
}

/// Releases a response allocated by [`mahayana_codex_run`] or
/// [`mahayana_execute`].
///
/// # Safety
/// `pointer` must be null or a live pointer returned by one of the Mahayana FFI
/// functions above. Each non-null pointer must be released exactly once.
#[no_mangle]
pub unsafe extern "C" fn mahayana_free_string(pointer: *mut c_char) {
    if !pointer.is_null() {
        drop(CString::from_raw(pointer));
    }
}

fn into_owned_c_string(response: Value) -> *mut c_char {
    let response = serde_json::to_string(&response).unwrap_or_else(|_| {
        "{\"ok\":false,\"errorCode\":\"mahayana_response_serialization_error\",\"message\":\"Could not serialize Mahayana response.\"}".to_string()
    });
    CString::new(response)
        .expect("serialized JSON does not contain NUL")
        .into_raw()
}

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
    let mahayana_symbols = [
        mahayana_codex_run as *const () as usize,
        mahayana_execute as *const () as usize,
        mahayana_free_string as *const () as usize,
    ];
    std::hint::black_box((telegram_symbols, miniapp_symbols, mahayana_symbols));
    1
}

/// The bundled Global Dharma MCP server name consumed by the Mahayana fork.
pub const GLOBAL_DHARMA_MCP_SERVER: &str = "global-dharma";
/// The TUI mention used to select the Global Dharma capability group.
pub const GLOBAL_DHARMA_MENTION: &str = "@global-dharma";

#[cfg(test)]
mod tests {
    use std::ffi::{CStr, CString};

    #[test]
    fn unified_library_keeps_legacy_ffi_symbols_linked() {
        assert_eq!(super::mahayana_force_link(), 1);
    }

    #[test]
    fn codex_ffi_rejects_a_malformed_request_without_starting_a_cli() {
        let request = CString::new("[]").unwrap();
        let response = unsafe { super::mahayana_codex_run(request.as_ptr()) };
        assert!(!response.is_null());
        let response_json = unsafe { CStr::from_ptr(response) }
            .to_str()
            .unwrap()
            .to_string();
        unsafe { super::mahayana_free_string(response) };
        assert!(response_json.contains("mahayana_codex_sdk_error"));
    }

    #[test]
    fn generic_ffi_executes_kernel_status() {
        let request = CString::new(r#"{"@type":"mahayana.status"}"#).unwrap();
        let response = unsafe { super::mahayana_execute(request.as_ptr()) };
        assert!(!response.is_null());
        let response_json = unsafe { CStr::from_ptr(response) }
            .to_str()
            .unwrap()
            .to_string();
        unsafe { super::mahayana_free_string(response) };
        assert!(response_json.contains("codex-rust-sdk"));
        assert!(response_json.contains("mahayana-product-client"));
    }
}
