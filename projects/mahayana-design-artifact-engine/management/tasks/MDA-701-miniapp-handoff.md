# MDA-701 MiniApp design/publish handoff

Status: in-progress

Objective: connect generated MiniApp artifacts to the existing Fabushi MiniApp/WebMCP/marketplace pipeline.

Implementation: MiniApp artifact manifests declare `fabushi-miniapp` runtime and marketplace handoff; trusted Host produces `fabushi-miniapp-publish-handoff/v1` with capability review and existing-pipeline requirements. Artifact Studio exposes the handoff action.

Non-goal: bypassing BotFather/marketplace approval, WebMCP policy, or installing raw generated HTML as a privileged app.

Verification: contract tests plus desktop/MiniApp E2E. PR/CI evidence pending.
