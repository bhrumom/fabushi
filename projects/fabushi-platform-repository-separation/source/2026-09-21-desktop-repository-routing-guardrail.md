# PRS-REQ-012 — Desktop repository routing guardrail

Date: 2026-09-21

## Original user requirement

The user explicitly required the root agent instructions in `bhrumom/fabushi` to state that the Desktop repository has already been split/migrated out, so AI agents do not go to the wrong repository.

## Normalized requirement

1. The root `AGENTS.md` in `bhrumom/fabushi` must clearly identify `bhrumom/fabushi-desktop` as the canonical repository for Desktop product development.
2. Desktop/Electron/macOS/Windows/Linux Desktop implementation, testing, packaging, updater, and release work must not continue in `bhrumom/fabushi`.
3. Legacy Desktop source still present in `bhrumom/fabushi` must be treated as migration/reference material rather than authoritative current Desktop source.
4. Agents must verify repository identity before Desktop implementation and fail closed if they are still in `bhrumom/fabushi`.
5. After routing to `bhrumom/fabushi-desktop`, agents must read that repository's own root `AGENTS.md` and applicable Specs before implementation.
6. Migration/governance/history records that intentionally belong to the source repository remain editable here when explicitly targeted.

## Scope note

This requirement establishes development ownership/routing for Desktop. It does not by itself declare every remaining PRS production cutover, independent CI, release, or source-cleanup gate complete.
