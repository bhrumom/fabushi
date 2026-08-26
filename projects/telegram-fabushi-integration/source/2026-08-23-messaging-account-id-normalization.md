# Source — Authenticated messaging account identity normalization

On 2026-08-23, final smoke testing of the signed and notarized canonical-main macOS package exposed a production-only messaging access regression after the app was installed and opened on the target Mac.

The app restored the existing authenticated Fabushi session, but the unified Messenger displayed:

`bridge/invoke-failed: host operation failed: authenticated account has no stable user id`

## Root cause

`mahayana-feature-host::issue_messaging_access` derived the local messaging actor from the UI-safe account object. It selected `user.id`, `user.userId`, or `user.username` with one `or_else` chain and then applied a single `Value::as_str()` to the selected value.

The production account worker serializes `id`, `userId`, and `userNo` as JSON numbers. Because `user.id` exists first, the chain selected that numeric value; `as_str()` then returned `None`, and the code never continued to the valid later identity fields. The result was a false “no stable user id” contract failure even though the authenticated account had a stable numeric identity.

## Repair direction

Normalize stable account identity components instead of assuming every identifier is a JSON string. The Host now accepts non-empty strings and JSON numbers, checks canonical/future principal identifiers as well as current and legacy user identifiers, searches both the nested `user` object and the UI-safe session root, and still fails closed when no stable identifier exists.

The resulting identifier is used only as input to the existing SHA-256 account fingerprint; raw account identifiers and account credentials are not exposed to the presentation layer or persisted in the messaging access registry.

## Verification contract

- numeric production `user.id` / `userId` values are accepted;
- legacy string usernames and top-level session identifiers remain compatible;
- missing stable identity still fails closed;
- the existing authenticated desktop session issues self-hosted messaging access without requiring re-login;
- current-head CI passes;
- after protected merge, canonical main builds the full macOS Developer ID package, passes App Store Connect notarization/stapling/Gatekeeper verification and packaged E2E;
- that exact artifact is installed and opened on the target Mac, and the stable-user-id runtime banner is absent.
