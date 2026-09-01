# RustDesk -> Fabushi 核心能力融合

- Project ID: `FAB-P0009`
- Project Key: `RDF`
- Status: active / in progress
- Current stage: M1 device identity and presence
- Next gate: RDF-001 contract CI on the task PR

## Objective

Unify all devices under one Fabushi account and progressively deliver secure remote-desktop, input, clipboard, file, display, audio and session capabilities informed by the pinned RustDesk upstream, while Fabushi remains the identity, authorization, audit and product authority.

## Current verified baseline

Fabushi already has account-scoped computer registration, device-secret possession proof, heartbeat, D1 presence, paired clients, expiring WebRTC sessions, direct/TURN signaling, remote screen/input and desktop/mobile/Web surfaces. The first slice extends that existing path with a vendor-neutral inventory contract for platform, version, provider, capabilities and active-session state.

RustDesk client and OSS server are AGPL-3.0. No RustDesk source is copied or linked into Fabushi in RDF-001. Later native provider work requires a separately distributable AGPL component or a separately licensed implementation and legal review.

## Acceptance

No capability is marked complete without code, contract tests, Actions run evidence, protected merge, canonical-main readback and applicable packaged E2E/Release evidence.

See `SOURCE_OF_TRUTH.md`, `docs/`, `management/`, `decisions/`, `evidence/` and `runbooks/`.
