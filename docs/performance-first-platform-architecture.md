# Fabushi Performance First Platform Architecture Proposal

Date: 2026-08-11

## Executive decision

Do not perform a full rewrite. The current Flutter application is kept as a migration shell, but it should no longer be the long-term platform architecture.

Target architecture:

- Mahayana Rust runtime becomes the platform core.
- TypeScript/React becomes the main UI and mini-app surface.
- Mini apps become signed local-first web bundles with a versioned host bridge.
- WeChat Mini Program becomes an adapter target, not the core runtime.
- Flutter gradually moves to compatibility mode.

## Current assessment

The repository already contains most required building blocks:

- Mahayana Rust workspace with runtime, miniapp, bridge and platform modules.
- Web frontend workspace.
- WeChat mini program workspace.
- Versioned mini-app protocol.
- Host capability bridge.

The main architectural issue is that the product core is still mixed with a heavy Flutter client.

## Why Flutter should not remain the primary platform layer

Flutter is excellent for native application delivery, but this product is becoming a mini-app operating platform.

The product requirements are:

- installable mini applications
- chat driven interactions
- local runtime execution
- marketplace distribution
- Web/WASM support
- WeChat compatibility

A Web-first mini-app model fits these requirements better.

## Target architecture

```
                 Mini App Marketplace
                         |
                  Mini App Manifest
                         |
       +-----------------+-----------------+
       |                                   |
 React/Web UI                     WeChat Adapter
       |                                   |
       +------------ Mini App SDK --------+
                         |
                 Host Bridge Protocol
                         |
              Mahayana Rust Runtime
                         |
     +-------------------+-------------------+
     |                   |                   |
 Desktop Runtime     Mobile Runtime       WASM Runtime
```

## Runtime principles

1. Business logic lives in Rust.
2. UI only controls state and rendering.
3. Mini apps request capabilities, never raw system access.
4. Local execution is preferred over cloud execution.
5. Every mini app is versioned and permissioned.

## Migration plan

### Phase 1

- Keep Flutter production builds working.
- Make Mahayana runtime the source of truth.
- Move new features to mini-app protocol.

### Phase 2

- Build React host UI.
- Move chat, marketplace and mini-app surfaces.
- Reduce Flutter responsibilities.

### Phase 3

- Flutter becomes optional compatibility client.
- Desktop/mobile/web share the same mini-app runtime contracts.

## Recommended stack

Core:

- Rust
- WASM
- JSON-RPC bridge
- signed manifests

Frontend:

- React
- Next.js
- Taro for WeChat
- shared TypeScript SDK

Desktop:

- native Rust runtime
- optional Tauri shell if needed

Mobile:

- thin native host
- embedded Rust runtime

## Performance goals

- startup time: minimize JS/native initialization
- small mini-app payloads
- lazy loading
- background work handled by Rust
- no long-running business loops inside WebViews

## Non-goals

Do not:

- rewrite everything immediately
- create unnecessary microservices
- duplicate business logic in Flutter and Rust
- allow arbitrary mini-app system access

## Final recommendation

The correct direction is not Flutter versus Rust.

The correct architecture is:

Rust is the operating system layer.
React/Web is the application surface.
Mini apps are the distributed applications.
Flutter is a transition client.
