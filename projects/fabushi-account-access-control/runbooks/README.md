# Runbook

Verify an authenticated `bhrum108` session returns `isAdmin=true`, `role=super_admin`, `unlimitedUsage=true`; membership endpoints return active lifetime; `/v1/ai/usage` returns `unlimited=true` and null quota/remaining values. Never log bearer tokens while validating.
