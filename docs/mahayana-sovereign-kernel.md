# Mahayana Sovereign Kernel

## Goal

Mahayana is a Fabushi-owned product and runtime contract. Codex, Grok Build,
model providers, MCP servers, and future agent engines are integrations behind
Mahayana-owned interfaces; none of them defines the public product ABI.

This distinction is architectural, not cosmetic. Renaming upstream crates or
copying two source trees together would leave Mahayana coupled to somebody
else's session model, protocol, release cadence, and product assumptions.
Instead, the product owns its IDs, events, capability model, policies,
routing, workspace semantics, and cross-platform ABI first.

## Current state

The existing `mahayana-rs` workspace already owns conversation routing,
product authentication, Telegram, MiniApps, FFI/WASM, plugin hosting, and
cross-platform hosts. It also has a useful `AgentBackend` seam. However the
workspace still directly imports many `codex-*` crates and the large
`mahayana-agent-codex` adapter projects Codex app-server concepts deep into the
runtime.

The sovereign-kernel migration reverses that dependency direction.

```text
Electron / iOS / Android / Web / CLI / MiniApps
                    |
             Mahayana Protocol
                    |
             Mahayana Kernel
     +--------------+---------------+
     |              |               |
  Session        Workspace       Policy
  Workflow       Tool Bus        Memory/Graph
     |              |               |
     +------- Capability Router -----+
                    |
        +-----------+-----------+
        |           |           |
   Mahayana      Codex       Grok-derived
    Native       Adapter      adapters
    Engine      (legacy)     (transitional)
        |
   Model Providers / MCP / local tools
```

`mahayana-kernel` contains no Codex or xAI product types. Compatibility
adapters must translate at the edge.

## Capability fusion

### What to retain from Codex

Codex has a broad, mature local-agent substrate: app-server/client protocol,
thread and state storage, sandbox/approval controls, MCP and connector support,
skills, file search/watch, model-provider abstractions, cloud task integration,
and an extension surface. These are valuable capabilities, but Mahayana should
own the corresponding contracts and selectively port or adapt implementations.

### What to retain from Grok Build

Grok Build adds strong product-oriented execution primitives around a coding
agent: active sessions, prompt queues, codebase graphing, fast worktrees,
workspace/checkpoint management, memory, hooks, workflows, long-running task
support, sub-agent resolution, a dedicated tool runtime, headless operation,
and ACP/editor embedding. These concepts fit Mahayana especially well for
multi-device work and long-running automation.

### What Mahayana adds

Mahayana's differentiator is not a union of two CLIs. Its native design is:

- **Conversation-first:** AI agents, human contacts, bots and MiniApps share a
  product-owned conversation/session envelope.
- **Cross-platform embedded runtime:** desktop, native mobile and Web use the
  same command/event semantics with platform-specific capability negotiation.
- **Local agent, remote model:** a network model endpoint must never silently
  become a remote agent runtime.
- **Capability routing:** the kernel chooses an engine by declared capabilities
  and policy instead of hard-coding a vendor.
- **Policy as a first-class contract:** approval/risk/network/process/workspace
  rules are defined above engine adapters.
- **Checkpointable workflows:** task graphs, worktrees, context graphs and
  resumable sessions can be shared across AI, plugins and device surfaces.
- **Unified tool bus:** MCP, product tools, local computer control, plugins and
  MiniApp actions converge on Mahayana-owned tool semantics.

## Nine product-owned capability domains

1. **Kernel** — lifecycle, capability routing, backend registry, stable events.
2. **Session** — threads, active sessions, resumability, operation ownership.
3. **Workspace** — filesystem, Git, worktrees, checkpoints, codebase graph.
4. **Tool** — tool schema, execution, MCP bridge, progress and isolation.
5. **Memory** — durable/user/project memory and context compaction.
6. **Workflow** — prompt queue, DAG tasks, hooks, sub-agents, long-running work.
7. **Extension** — skills, plugins, MiniApps, connectors and ACP-facing APIs.
8. **Model** — provider-neutral model selection, streaming and usage accounting.
9. **Policy** — approvals, risk, sandbox/capability grants, secrets and audit.

## Migration rules

1. New UI/mobile/Web code must depend on Mahayana contracts, never on new
   `codex-*` or `xai-*` types.
2. Any upstream implementation that is reused remains an attributed third-party
   component until independently replaced; renaming does not change origin.
3. Compatibility adapters may depend on upstream crates, but product-owned
   kernel/domain crates may not.
4. Native replacements are introduced capability-by-capability behind the same
   kernel contract, allowing side-by-side conformance tests.
5. The end state permits deleting `third_party/mahayana/codex-rs` without
   changing the desktop/mobile/Web public Mahayana protocol.

## Migration phases

### Phase 0 — Sovereign boundary

- Introduce `mahayana-kernel`.
- Define product-owned IDs, capabilities, policy, events and backend interface.
- Mark Codex as a compatibility backend rather than the product core.

### Phase 1 — Compatibility bridge

- Project the existing `mahayana-agent` API into `mahayana-kernel`.
- Adapt `mahayana-agent-codex` behind `EngineBackend`.
- Add conformance tests for events, approvals and interruption.

### Phase 2 — Native Session / Tool / Policy

- Move session ownership and operation state out of Codex app-server types.
- Implement the Mahayana tool bus and approval policy natively.
- Keep Codex only for capabilities not yet replaced.

### Phase 3 — Native Workspace / Workflow / Memory

- Add fast worktree/checkpoint primitives, codebase graph, prompt queue,
  resumable workflow DAG, hooks, memory and sub-agent scheduling.
- Expose the same features to desktop/headless/ACP while capability-gating
  mobile and Web.

### Phase 4 — Native Extension / Model stack

- Normalize MCP, skills, plugins, connectors, MiniApps and model providers onto
  Mahayana contracts.
- Remove provider-specific protocol leakage from app surfaces.

### Phase 5 — Upstream isolation

- Audit remaining `codex-*` dependencies.
- Replace or confine each one to optional compatibility packages.
- Remove vendored Codex from the default product build when conformance gates
  prove native parity.

## Licensing and provenance

Both current upstream projects identify their first-party source as
Apache-2.0. Grok Build also documents in-tree ports derived from Codex and
OpenCode. Reused or modified source therefore keeps the required copyright,
license and notice obligations. Mahayana can be a distinct product and own its
architecture while still accurately preserving provenance for third-party
code. New native Mahayana modules should be written against the product-owned
contracts so the amount of upstream-derived implementation monotonically
shrinks over time.
