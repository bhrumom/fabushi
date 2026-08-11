# Fabushi AI Mini App Platform Architecture Rewrite Proposal

## Background

Fabushi is evolving from a single global publisher application into a cross-platform AI mini-app platform. The target product is closer to a Telegram + mini-app ecosystem:

- Users communicate through an AI-native chat layer.
- Chat can discover, install, launch and control mini-apps.
- Mini-apps can run locally after installation while communicating with platform services.
- The platform should support mobile, Web, desktop and WeChat mini-program scenarios with minimal duplicated development.

## Current Architecture Concerns

The existing Flutter-based approach provides cross-platform UI capability, but there are concerns for the new platform direction:

- Flutter Web has performance and development iteration issues for complex platform-style applications.
- The runtime model is less aligned with a web-native mini-app ecosystem.
- Building a local-installable mini-app runtime around Flutter increases complexity.

## Recommendation

Do not rewrite everything immediately. Gradually separate the platform into layers.

## Target Architecture

```
                 AI Agent / Chat Layer
                         |
                    Platform Core
                         |
        +----------------+----------------+
        |                                 |
 Mini App Runtime                  Platform Services
        |                                 |
 WebAssembly / Web Runtime          Rust Backend
        |
 Mini Apps (HTML/CSS/JS/WASM)
```

## Language Strategy

### Rust (Core)

Use Rust as the platform foundation:

- Gateway services
- AI orchestration runtime
- Mini-app sandbox/runtime services
- High performance APIs
- CLI tools
- Local agent communication

### TypeScript (Frontend + Mini Apps)

Use TypeScript instead of Flutter for:

- Web client
- Mobile web runtime
- Mini-app SDK
- Developer ecosystem

Reasons:

- Best compatibility with WeChat mini-program concepts.
- Huge frontend ecosystem.
- Easy WebView/local installation model.
- Faster iteration.

### Native Shell (Optional)

For desktop/mobile packaging:

- Tauri + Rust for desktop.
- Capacitor or custom Rust shell for mobile if needed.

## Mini App Model

Each mini-app should be:

- A signed package.
- Installable locally.
- Executed inside a sandbox runtime.
- Controlled by permissions.
- Able to receive AI/chat events.

Example:

```
User
 |
AI Chat
 |
Open Mini App
 |
Local Runtime
 |
Mini App Package
 |
Platform API
```

## Migration Plan

### Phase 1

Keep Flutter application working.

Build:

- Rust API core.
- Mini-app protocol.
- TypeScript SDK.

### Phase 2

Move major UI surfaces:

- Chat interface.
- Mini-app marketplace.
- Runtime container.

### Phase 3

Flutter becomes legacy compatibility layer or removed.

## Performance Goals

Priority order:

1. Runtime responsiveness.
2. Development speed.
3. Cross-platform coverage.
4. Native performance where required.

## Final Recommendation

For the long-term Fabushi vision, a Rust + TypeScript + WebAssembly architecture is more suitable than a Flutter-centered architecture.

Flutter is still useful for the existing application migration period, but the future platform core should be web-native and Rust-driven.
