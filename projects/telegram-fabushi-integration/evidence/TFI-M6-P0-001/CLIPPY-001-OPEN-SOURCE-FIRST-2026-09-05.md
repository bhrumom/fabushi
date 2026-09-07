# CLIPPY-001 open-source-first evidence — 2026-09-05

Scope: Rust dead-code/public-vs-private lifecycle, Clippy `-D warnings`, nested match simplification, messaging/community administrator permission modeling, CI/test strategy, security, license and compatibility. Concepts only; no upstream code is copied, translated, ported or adapted.

## Candidate 1 — Rust compiler official lint documentation
- Source: `https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#dead-code`.
- Maintainer: Rust Project.
- License: Rust project is dual MIT / Apache-2.0.
- Relevant guidance: `dead_code` detects unused unexported items; unused private code can indicate mistakes/unfinished code and ordinarily should be removed unless there is a real exposure/lifecycle reason.
- Fabushi decision: **BORROW LINT-LIFECYCLE PRINCIPLE ONLY**. `CommunityAdminAction` is private and `PostMessages` has no constructor/caller, so removal of that private selector is preferable to suppression. Do not apply the guidance to the live `AdminRights.post_messages` domain field or direct send permission path.

## Candidate 2 — Rust Clippy official lint + CI documentation
- Sources: `https://rust-lang.github.io/rust-clippy/master/index.html#collapsible_match` and `https://doc.rust-lang.org/clippy/continuous_integration/index.html`.
- Maintainer: Rust Project.
- License: Clippy is dual MIT / Apache-2.0.
- Relevant guidance: `collapsible_match` targets nested `match`/`if let` forms whose patterns can be collapsed without adding branches; Clippy's CI guide recommends running Clippy with `-D warnings` and using a toolchain compatible with the crate's compile toolchain.
- Fabushi decision: **BORROW CONTROL-FLOW/CI PRINCIPLES ONLY**. Keep the existing `-D warnings` gate; rewrite only the nested service authorization shape. Reject workflow weakening or `allow/expect` suppression.
- Security/test consequence: because the rewrite is authorization-adjacent, preserve the exact boolean predicate/error and require all existing Rust contracts rather than replacing tests.

## Candidate 3 — tdlib/td
- Source: `https://github.com/tdlib/td` and `LICENSE_1_0.txt`.
- Project: maintained cross-platform Telegram client library.
- License: Boost Software License 1.0.
- Relevant architecture: administrator capabilities are modeled as explicit domain rights, separate from whichever command/dispatch helper consumes a particular right.
- Fabushi decision: **BORROW DOMAIN-RIGHT SEPARATION CONCEPT ONLY**. This supports retaining Fabushi's live `AdminRights.post_messages` even when one private generic selector is unused. No TDLib code/API/dependency is imported; Fabushi already owns its Rust state machine.
- Compatibility: conceptual only; C++ runtime/protocol integration is unnecessary for a two-line private-selector cleanup.

## Candidate 4 — matrix-org/matrix-rust-sdk
- Source: `https://github.com/matrix-org/matrix-rust-sdk`.
- Project: maintained production-ready Matrix client SDK in Rust.
- License: Apache-2.0.
- Relevant lessons: permissions/state remain explicit domain state, while client/runtime layers consume those capabilities; production Rust projects retain strong lint/test discipline around stateful messaging code.
- Fabushi decision: **BORROW TEST/STATE-SEPARATION IDEAS ONLY**. Rust/license compatibility is good, but importing SDK code or protocol semantics would create unnecessary coupling and does not address this local lint gate.

## Candidate 5 — Telegram Desktop
- Source: `https://github.com/TelegramOrg/Telegram-desktop`.
- License: GPLv3 with OpenSSL exception.
- Relevant domain: mature Telegram messaging/admin implementation.
- Fabushi decision: **REJECT CODE REUSE**. Strong copyleft obligations plus C++/Qt/product-architecture mismatch are disproportionate for this task. It is not used as an implementation source; no code is copied.

## Security, license and compatibility result
- No new dependency, vendored source, generated code or license obligation is introduced.
- Rust/Clippy official MIT/Apache-2.0 guidance and Matrix Apache-2.0 are license-compatible for conceptual reference; TDLib BSL-1.0 is permissive, but no code is imported; Telegram Desktop GPLv3 source reuse is explicitly rejected.
- The security boundary is stricter than a cosmetic lint cleanup: the service authorization predicate and the live post-message permission must remain behaviorally identical, proven by existing contracts and exact-head Actions.
- The project's Rust 2021/stable toolchain remains unchanged; no toolchain/workflow workaround is part of the task.

## Result for Fabushi
Adopt only these ideas:
1. remove genuinely unused private selector code rather than hide it;
2. keep real domain permission fields separate from helper-dispatch lifecycle;
3. collapse nested authorization control flow only when branch semantics remain identical;
4. keep `-D warnings` as a hard CI quality gate;
5. validate security-adjacent cleanup with the full existing contract suite and downstream product gates.

No upstream implementation code is copied.