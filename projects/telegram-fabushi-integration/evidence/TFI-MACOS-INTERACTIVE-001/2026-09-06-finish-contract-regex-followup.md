# TFI-MACOS-INTERACTIVE-001 — late finish-contract regex syntax follow-up

- Protected base at repair start: `main@111b4a9ab18247da0ea90b45cbd3abaaa61784a0`.
- Preceding renewal repair: PR #2401 merged as `9a41713f592ef21842c68e36bdc647720af8954d`.
- Late PR-head failure: run `34016108966`, job `101440042007` (`linux-managed-semantic-desktop`).

## Truthful failure

The renewal implementation itself was not the failing line. Node 24 source parsing rejected the newly added workflow-contract assertion because its `/u` regular-expression literal unnecessarily escaped the double quotes in `agentId == \"settings-logout\"`. JavaScript `/u` regular expressions reject that identity escape, so the semantic desktop source gate failed before running the contract.

## Atomic correction

Change only that assertion to the valid literal `/agentId == "settings-logout"/u`. The checked workflow string remains unchanged and still requires exact production `settings-logout`; no runtime, session-renewal, release, device-selection, logout, or evidence behavior is changed.

Verification is GitHub Actions only. Do not publish the next macOS test release until this exact-head contract gate and protected merge complete successfully.