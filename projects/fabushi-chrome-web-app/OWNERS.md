# Owners and review

| Role | Owner | Responsibility |
|---|---|---|
| Accountable | Fabushi desktop/platform maintainers | Product behavior, release decision and rollback |
| Execution | Fabushi browser-platform maintainers | Extension, native hosts, tests and records |
| Security reviewer | Fabushi security maintainers | Debugger/native messaging, origin, secret and input review |
| Release reviewer | Fabushi release maintainers | Web Store, packages, exact-SHA evidence and updater |
| Consulted | FCM, MSR, AAC | CI/release, runtime and account/session boundaries |

Escalate protected-main, Web Store or profile-migration blockers to the release maintainer;
escalate credential or debugger findings to security before shipping.
