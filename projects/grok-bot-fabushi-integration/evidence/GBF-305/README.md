# GBF-305 Evidence — local exec boundary

Desktop JS process execution audit finds only two approved process surfaces: `host-process.cjs` (launches the single Rust Mahayana AppHost) and `offline-asr.cjs` (isolated whisper-compatible ASR binary, no shell). The runtime convergence CI guard rejects any additional `child_process`/spawn surface in desktop/frontend.

FeatureHost local computer execution checks `settings.local_execution`, `settings.ai_computer_control_enabled`, `LocalToolPermission::Never`, and requires explicit approval under `Ask`; M2 native tests separately prove administrator permission ceiling enforcement.
