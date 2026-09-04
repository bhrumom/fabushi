# GBF P0 acceptance / risk / dependency / changelog — FAB-ARCH-P0-20260904

## Acceptance
GBF-508 requires clean-room provenance, mention/reply/command trigger matrix, privacy ambient-ignore matrix, one-session context proof, typed tool results, and device/MiniApp capability routing through MSR policy.

## Risks
- `GBF-P0-R1` CRITICAL: privacy leak from ambient group forwarding.
- `GBF-P0-R2` CRITICAL: account login incorrectly treated as device-control grant.
- `GBF-P0-R3` HIGH: direct provider invocation bypasses MSR approval/audit.
- `GBF-P0-R4` LEGAL: reconstructed Grok material lacks root source license; copying implementation is forbidden.

## Dependencies
Existing GBF-409/411, MSR-210/211, and TFI M6/M7 transport contracts.

## Change log 2026-09-04
Recorded clean-room revision/license conclusion and cross-project ownership; added GBF-508. No implementation/test/release state was promoted.