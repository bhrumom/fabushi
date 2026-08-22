# Upstream baseline — DeepSeek Harness

Audit date: 2026-08-22

## Pin
- Repository: `deepseek-ai/deepseek-harness`
- Observed version: `0.1.1-rc.2`
- Commit: `b150a551b8d465e31e418e1b2eaf5e79bbb7d28e`
- Commit timestamp: 2026-08-21T12:03:37Z
- License: MIT (`LICENSE`, copyright DeepSeek 2026)
- Upstream explicitly labels the project developer preview and warns of compatibility-breaking changes.

## Architecture facts used for intake
Upstream documents an “everything is a plugin” Cordis composition model. Profiles stack bundles and patch overlays. Core extension domains include session log, system prompt assembly, tool registry/execution pipeline, agent registry/loop, scoped registration and LLM streaming adapters.

Upstream's documented turn model includes durable turn/step/user/assistant/tool events plus live interception points. Model-visible history is derived from an append-only session log. Capability seams separate service definitions, providers and consumers. Documented seams/features include models, tools, shell/subprocess/PTY, filesystem, sandbox, subagents/teams, jobs, goals, workflows, plugins, persistence/query, settings, credentials, workspace, SDK/JSON-RPC, ACP, schedule, feedback, identity and Web/headless surfaces.

## Planning rule
Mahayana will reproduce required behavior through Rust-native, Mahayana-owned contracts. Cordis/Node.js are reference implementation details, not required product runtimes.

## Follow-up audit requirement
DHRF-101 must inventory packages, tools, events, configuration rows, persistence contracts, user-visible flows and tests at this exact commit before the project claims complete parity.
