#[cfg(fabushi_tauri_wdio_e2e)]
mod e2e;

#[cfg(fabushi_tauri_wdio_e2e)]
fn main() {
    e2e::run();
}

#[cfg(not(fabushi_tauri_wdio_e2e))]
fn main() {
    fabushi_tauri_lib::run();
}
