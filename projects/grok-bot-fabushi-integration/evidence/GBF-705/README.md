# GBF-705 evidence — Credential Vault / last-hop injection

## Scope

This evidence folder tracks the non-revealable Fabushi Credential Vault and target-bound last-hop credential injection implementation.

## Source / implementation evidence

- Source record: `projects/grok-bot-fabushi-integration/source/2026-08-28-credential-vault-last-hop-injection.md`
- Task: `projects/grok-bot-fabushi-integration/management/tasks/GBF-705-credential-vault-gateway.md`
- Runtime boundary: `desktop/electron/credential-gateway.cjs`
- Renderer edge: `desktop/electron/native-edge.cjs`
- Typed edge: `desktop/src/edge/contracts/native-capabilities.ts`
- Product UI: `desktop/src/credential-vault.tsx`
- Security tests: `desktop/electron/credential-gateway.test.cjs`

## Security assertions represented by automated tests

Synthetic canary values verify that:

- encrypted storage JSON does not contain credential plaintext;
- `listSecrets` returns metadata and `revealable: false` only;
- plaintext `revealSecret` is unavailable to the Renderer and rejects inside the wrapper;
- exact HTTPS origin binding is required;
- unbound legacy Provider credentials cannot be used by generic credential requests;
- HTTP targets are rejected;
- cross-origin use is rejected;
- caller-provided Authorization headers are rejected;
- credential-bearing requests use `redirect: manual`;
- response metadata does not echo the credential or `Set-Cookie`;
- non-credential egress continues to use the existing managed egress route.

## Pending authoritative evidence

The following are intentionally not marked complete until GitHub/package evidence exists:

- PR required CI run IDs;
- Electron Feature Host / Native Edge contract result;
- desktop TypeScript/build result;
- packaged credential-vault screenshot/video/trace;
- protected-main SHA readback;
- post-main release asset SHA;
- canary privacy/log scan from the packaged build.

Do not mark GBF-705 RELEASED until those items are populated from objective evidence.
