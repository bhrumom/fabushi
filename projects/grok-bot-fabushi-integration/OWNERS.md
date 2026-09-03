# Ownership / RACI

| Area | Accountable | Responsible | Required reviewers | Consulted | Escalation |
|---|---|---|---|---|---|
| Project scope / acceptance | Fabushi project owner | Fabushi/Mahayana maintainers | Fabushi maintainers | Product/UX as affected | project owner |
| Mahayana kernel / Agent runtime | Mahayana maintainers | runtime implementer | Mahayana reviewer | Electron/MCP owners | project owner |
| Electron / preload / IPC | Desktop maintainers | desktop implementer | desktop + security for privilege changes | Mahayana owner | project owner |
| Host / local execution | Mahayana/Desktop maintainers | capability implementer | security reviewer | platform adapter owners | project owner |
| Computer control | Platform capability owner | platform implementer | **security reviewer required** | desktop/browser owners | project owner |
| Sensitive input / credentials boundary | Security owner | capability/security implementer | **security reviewer required** | platform owner | project owner |
| UI / avatar animation | Desktop UI owner | renderer implementer | desktop reviewer | design/accessibility | project owner |
| CI / E2E / release | CI/release maintainers | affected domain owner | repository-required review | platform owners | project owner |
| Provenance / license | Project owner | task implementer | provenance/license reviewer when external code retained | maintainers | project owner |

没有明确责任人或必要审查者的高风险能力不得提升到 `RELEASED`。
