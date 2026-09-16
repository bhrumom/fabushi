# Source of truth

Project identity is immutable: FAB-P0011 / CWA, registered in projects/PORTFOLIO.json;
the allocation baseline recorded there is canonical main
`656d05e8d66bfed241f5b9d871a062abfbf2f952`.
The canonical implementation source is bhrumom/fabushi on main, under
projects/fabushi-chrome-web-app/ and the paths named by CWA-006.

The original user requirement is preserved in source/2026-09-12-user-requirement.md.
The prior implementation branch codex/fabushi-chrome-userscripts is an input and
comparison source, not canonical state; only compatible modules are adapted.
Open-source references are the official Chrome Native Messaging and Debugger API
documentation and the GoogleChrome samples listed in source/README.md.

CWA-009 is the current marketplace security addition: GitHub remains the source and immutable
package host; `services/marketplace-security-gate/` is the self-hosted audit/signing worker;
the Worker/D1 queue is the promotion and revoke control plane. The user's explicit no-script/plugin
E2E instruction is authoritative for this round, so no E2E execution may be used as a completion
claim.

Precedence is: latest user requirement persisted here; canonical portfolio registry and
identity policy; this file and source intake; accepted ADRs/specs; management state; live
GitHub code/PR/CI/release/deployment facts; external mirrors; chat memory. If records
disagree, preserve the historical record, verify live facts, and append a correction.
A task is not complete while protected merge, post-main package/E2E evidence, release or
migration gates remain open.
