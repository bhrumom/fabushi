# GBF-703 Evidence — provenance/license release audit

The historical Grok Bot 0.20 snapshot is audit input only. `evidence/GBF-105/vendor-0.20-provenance.tsv` contains exactly 148 entries; every entry is `PROVENANCE_BLOCKED` with a `reference-only` reuse policy. The production tree must not contain `vendor/grok-bot-0.20.0`, `frontend/apps/web/src/lib/grok-agent`, or `frontend/apps/web/src/lib/grok-bot`.

The M7 security validator enforces both sides of this rule: all historical entries stay blocked/reference-only and all forbidden production paths stay absent. Fabushi-owned clean-room implementations are separately documented in task evidence and are not reclassified as verbatim Grok source.
