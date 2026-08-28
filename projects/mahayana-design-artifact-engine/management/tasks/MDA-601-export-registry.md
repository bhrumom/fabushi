# MDA-601 Export capability registry

Status: in-progress

Objective: normalize artifact delivery formats while failing closed when a transformer is unavailable.

Implementation: kind-specific export registry for MiniApp/web/dashboard/document/deck/image/video/audio/data. Artifact Studio queries the trusted Host rather than inventing renderer-side conversion.

Acceptance: unsupported kind/format rejects; registry identifies Mahayana Host as execution owner; transformed formats remain capability-routed rather than silently faked.

Verification: artifact contract tests + product integration. PR/CI evidence pending.
