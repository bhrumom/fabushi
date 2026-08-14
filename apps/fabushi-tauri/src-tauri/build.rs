fn main() {
    println!("cargo:rustc-check-cfg=cfg(fabushi_tauri_wdio_e2e)");
    if std::env::var_os("FABUSHI_TAURI_WDIO_E2E").is_some() {
        println!("cargo:rustc-cfg=fabushi_tauri_wdio_e2e");
    }
    if std::env::var_os("CARGO_FEATURE_DESKTOP").is_some() {
        tauri_build::build();
    }
}
