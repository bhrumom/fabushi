// SPDX-License-Identifier: AGPL-3.0-only
// Fabushi-owned entry point for the pinned RustDesk host runtime. The daemon
// keeps RustDesk transport in a separate process and never receives Fabushi
// account credentials. Authorization remains in the Fabushi control plane.

fn main() {
    // `is_server=true` starts the local RustDesk host rather than attaching to
    // another already-running UI process. `no_server=false` retains upstream
    // rendezvous/direct/relay behavior and its platform permission model.
    librustdesk::start_server(true, false);
}
