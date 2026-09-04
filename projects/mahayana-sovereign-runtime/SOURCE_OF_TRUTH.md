# Source of Truth

## Authoritative engineering state
1. `bhrumom/fabushi` GitHub `main` for implementation facts.
2. This project folder for durable requirements, roadmap, WBS, ADRs and evidence indexes.
3. Accepted ADRs/current specs.
4. Live GitHub PR/CI/release facts.
5. External mirrors and chat memory.

## Original requirement
The user requires Mahayana to become a new Fabushi-owned product by studying and fusing the strengths of `https://github.com/xai-org/grok-build` and `https://github.com/openai/codex`, retaining the best capabilities of both while innovating beyond them rather than remaining a Codex-derived product.

## Canonical convergence history
- PR #1963: first independent-kernel proposal; closed, superseded.
- PR #1968: clean current-main migration; closed, superseded.
- PR #1971: canonical convergence implementation; merged to `main` as `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942`.
- PR #1967 is an obsolete reverse-sync PR into the superseded `feat/mahayana-independent-kernel` branch and is not an implementation source of truth.

## Upstream provenance baseline
- Historical Grok Build reviewed baseline: `19d42e35c07a9c9244f03f6df0c4c353f970d4f9`.
- Historical Codex reviewed baseline: `970b7f2d6c78fc9a4438841d4688e5547ca9dd07`.
- 2026-09-04 audit refresh pins Codex `8e85265c39176b6bd498242a33d7b0f9b4b98303` and Grok Build `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`; both root LICENSE files are Apache-2.0. These are audit revisions, not automatic imports.
- Current upstreams may move; every adaptation round records exact revision, license, files/capabilities used, NOTICE/provenance and reject decisions.

## 2026-09-04 cross-project authority

For program `FAB-ARCH-P0-20260904`, MSR owns the only Bot execution runtime/session. TFI owns messaging/MiniApp projection; GBF owns behavior and same-account device capability semantics. No project may introduce a second Bot engine.

## Conflict rule
When a project document conflicts with actual code/CI, record the discrepancy in status/changelog and correct the project record using live evidence; do not rewrite history silently.
