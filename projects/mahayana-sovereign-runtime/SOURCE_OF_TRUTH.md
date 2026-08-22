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
- Grok Build reviewed baseline currently recorded by Fabushi: `19d42e35c07a9c9244f03f6df0c4c353f970d4f9`.
- Codex reviewed baseline recorded by Fabushi: `970b7f2d6c78fc9a4438841d4688e5547ca9dd07`.
- Current upstreams may move; inventory tasks must pin the exact commit used for each audit round.

## Conflict rule
When a project document conflicts with actual code/CI, record the discrepancy in status/changelog and correct the project record using live evidence; do not rewrite history silently.
