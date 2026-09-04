# MSR-211 — unified Bot capability discovery/policy/result plane

- Project ID: `FAB-P0005`
- Task ID: `MSR-211`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependencies: `MSR-210 REVIEW-PASS`, existing `MSR-202`, GBF-409/411 contracts

## Goal

Make every Bot discover and invoke allowed same-account device and installed MiniApp capabilities only through one MSR catalog/policy/approval/audit plane.

## Contract

- merge provider descriptors from MCP/WebMCP/App MCP/MiniApp CLI/native Computer Use into normalized capability descriptors;
- filter by account/device/MiniApp/install/pair/control/policy state before model exposure;
- mutating/sensitive calls require the existing approval class; revoke/stale generation fails closed;
- result/progress/error envelope has stable invocation id, provider/tool identity, redacted structured output and provenance suitable for TFI rendering;
- no provider directly posts messages or bypasses MSR session/policy.

## Tests

Allowed/denied discovery, revoked device, uninstalled MiniApp, stale generation, secure input, approval deny/expire, duplicate invocation/retry, redaction, provider failure and result correlation. Actions + packaged integration evidence required before REVIEW-PASS.