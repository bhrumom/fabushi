# RustDesk -> Fabushi 核心能力融合

- Project ID: `FAB-P0009`
- Project Key: `RDF`
- Status: active / in progress
- Current stage: M2 provider/session abstraction
- Next gate: RDF-002 contract CI on the task PR

## Objective

Unify all devices under one Fabushi account and progressively deliver secure remote-desktop, input, clipboard, file, display, audio and session capabilities informed by the pinned RustDesk upstream, while Fabushi remains the identity, authorization, audit and product authority.

## Current verified baseline

RDF-001 is merged and CI-verified: Fabushi has account-scoped computer registration, device-secret possession proof, heartbeat, D1 presence, paired clients, expiring WebRTC sessions, direct/TURN signaling, remote screen/input and desktop/mobile/Web surfaces. The device inventory exposes provider, platform, app version, normalized capabilities and active-session state.

RDF-002 is now in progress. The current slice makes the selected transport provider durable session metadata: D1 binds each newly-created remote session to the provider registered by that account/device and makes that provider immutable for the life of the session. This establishes a provider-neutral server-side compatibility boundary without creating a second identity or authorization system.

RustDesk sidecar transport is not implemented yet. No RustDesk wire-protocol, hbbs/hbbr deployment, clipboard, file-transfer, or audio completion is claimed by this slice.

RustDesk client and OSS server are AGPL-3.0. No RustDesk source is copied or linked into Fabushi in RDF-001/RDF-002. Later native provider work requires a separately distributable AGPL component or a separately licensed implementation and legal review.

## Acceptance

No capability is marked complete without code, contract tests, Actions run evidence, protected merge, canonical-main readback and applicable packaged E2E/Release evidence.

See `SOURCE_OF_TRUTH.md`, `docs/`, `management/`, `decisions/`, `evidence/` and `runbooks/`.
