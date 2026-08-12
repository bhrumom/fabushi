use mahayana_core::RuntimeCommand;
use mahayana_host::HostCreateConfig;
use mahayana_host::MahayanaHost;
use mahayana_runtime::mahayana_runtime_close;
use mahayana_runtime::mahayana_runtime_create;
use mahayana_runtime::mahayana_runtime_execute;
use mahayana_runtime::mahayana_runtime_free_string;
use mahayana_runtime::mahayana_runtime_receive;
use serde_json::Value;
use std::ffi::CStr;
use std::ffi::CString;
use std::os::raw::c_char;
use std::time::Duration;

fn take(pointer: *mut c_char) -> Value {
    assert!(!pointer.is_null(), "FFI response pointer must not be null");
    let text = unsafe { CStr::from_ptr(pointer) }
        .to_str()
        .expect("FFI response must be UTF-8")
        .to_string();
    unsafe { mahayana_runtime_free_string(pointer) };
    serde_json::from_str(&text).expect("FFI response must be JSON")
}

#[test]
fn direct_host_and_legacy_ffi_return_the_same_status_and_ready_event() {
    let direct = MahayanaHost::create(HostCreateConfig::default()).expect("create direct Host");
    let direct_status = serde_json::to_value(
        direct
            .execute(RuntimeCommand::Status)
            .expect("direct status command"),
    )
    .expect("serialize direct status");
    let direct_ready = serde_json::to_value(
        direct
            .receive(Duration::from_millis(10))
            .expect("receive direct ready event")
            .expect("direct ready event"),
    )
    .expect("serialize direct ready event");

    let runtime_id = unsafe { mahayana_runtime_create(std::ptr::null()) };
    assert_ne!(runtime_id, 0, "create FFI Host");
    let command = CString::new(r#"{"@type":"mahayana.runtime.status"}"#)
        .expect("status command CString");
    let ffi_status = take(unsafe { mahayana_runtime_execute(runtime_id, command.as_ptr()) });
    let ffi_ready = take(unsafe { mahayana_runtime_receive(runtime_id, 10) });

    assert_eq!(ffi_status["ok"], true);
    assert_eq!(ffi_status["data"], direct_status);
    assert_eq!(ffi_ready["ok"], true);
    assert_eq!(ffi_ready["data"], direct_ready);

    let closed = take(unsafe { mahayana_runtime_close(runtime_id) });
    assert_eq!(closed["ok"], true);
    assert_eq!(closed["data"]["closed"], true);
}
