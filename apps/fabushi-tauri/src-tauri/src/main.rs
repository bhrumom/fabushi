#[cfg(feature = "tauri-wdio-e2e")]
mod e2e;

#[cfg(feature = "tauri-wdio-e2e")]
fn main() {
    e2e::run();
}

#[cfg(not(feature = "tauri-wdio-e2e"))]
fn main() {
    fabushi_tauri_lib::run();
}
