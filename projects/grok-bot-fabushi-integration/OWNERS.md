# Ownership

- Product owner: Fabushi project owner
- Engineering owner: Mahayana/Fabushi maintainers
- Runtime authority: `main`
- Project records: `projects/grok-bot-fabushi-integration/`

## 模块责任

- Electron/UI: `desktop/**`
- Mahayana kernel/agent runtime: sovereign Rust runtime and adapters
- Host/local execution: capability-gated desktop/native execution layer
- Computer control: dedicated capability module with explicit permissions
- Security/privacy: project-wide blocking reviewer responsibility
- CI/E2E: affected domain owners must supply objective evidence

任何模块没有明确所有者时不得标记 `RELEASED`。
