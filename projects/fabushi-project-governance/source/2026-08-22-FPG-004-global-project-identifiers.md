# FPG-004 Source Requirement — Global Project Identifiers

Date: 2026-08-22
Source: explicit user requirement in ChatGPT

## Original requirement

“开始落地项目编号，按照大厂行业规范标准去做”

The request follows the clarification that Fabushi needs a numbering scheme **between projects**, not only task IDs inside one project.

## Normalized requirement

Fabushi SHALL establish a repository-wide portfolio identity system with these properties:

1. Every canonical project under `projects/<slug>/` has one globally unique, immutable portfolio Project ID.
2. Portfolio IDs use the Fabushi namespace and a monotonic sequence: `FAB-P0001`, `FAB-P0002`, ... .
3. IDs are never reused, recycled, or reassigned after project rename, archive, merge, split, cancellation, or deletion request.
4. Existing project/task mnemonic identifiers remain available as `project_key` / legacy aliases so historical PRs, WBS items, and task IDs are not broken.
5. A machine-readable repository registry is authoritative for allocation and contains the high-water mark / next sequence.
6. Existing canonical projects are backfilled deterministically from the timestamp of their first formal project-folder commit on GitHub `main`.
7. New projects allocate exactly the next registry sequence in the same change that creates the project folder.
8. CI validates uniqueness, format, registry/folder parity, path/key consistency, monotonic allocation, and immutability against the target branch.
9. Root `AGENTS.md` and the Fabushi project-governance Skill/lifecycle must require registry lookup/allocation before creating a new project.
10. GitHub `main` plus the portfolio registry and each project `PROJECT.yaml` remain authoritative; external control planes mirror the same IDs.

## Acceptance intent

The migration is complete only when all existing canonical projects have assigned IDs, the registry and policy exist, automated validation passes, governance instructions are aligned, the change is merged through normal repository gates, and canonical `main` is re-verified.
