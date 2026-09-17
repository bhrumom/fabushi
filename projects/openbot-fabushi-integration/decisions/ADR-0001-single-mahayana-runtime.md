# ADR-0001 — Reuse Fabushi runtime; do not embed OpenBot runtime

Status: Accepted
Date: 2026-09-13

Context: OpenBot and Fabushi overlap in coworker/channel/tool/computer/governance concepts. Duplicating OpenBot's executor, gateway, persistence or computer supervisor would create two sources of truth.

Decision: Mahayana remains sole executor; Messenger remains sole transcript; existing ToolHost/policy/approval/audit/computer-control/MiniApp surfaces are reused. Only missing presentation or narrowly scoped product contracts may be added after evidence-based gap classification.

Consequence: exact OpenBot deployment internals such as mandatory container-per-coworker isolation are not copied automatically. Where Fabushi has a different architecture, the matrix records the semantic difference and acceptance uses Fabushi's canonical boundary.
