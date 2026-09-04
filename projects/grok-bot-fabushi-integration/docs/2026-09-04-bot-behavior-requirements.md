# GBF P0 requirements — FAB-ARCH-P0-20260904

- `GBF-R-P0-001`: privacy-mode group Bot receives only directed triggers (mention/reply/registered command/approved directed signal), not ambient messages.
- `GBF-R-P0-002`: direct/group/topic interactions reuse the Bot's one MSR durable session.
- `GBF-R-P0-003`: thinking/progress/tool/approval/result/error/final states remain visibly correlated and auditable.
- `GBF-R-P0-004`: same-account device discovery is separate from pairing/control authorization; login never equals control grant.
- `GBF-R-P0-005`: installed MiniApp semantic capabilities can be discovered/used by Bots through MSR policy; Computer Use is authorized fallback only.
- `GBF-R-P0-006`: reconstructed Grok material is clean-room behavior reference only when no root source license exists.