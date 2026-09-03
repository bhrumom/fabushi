# Fabushi Portfolio Project ID Policy

## Purpose

Provide one immutable, globally unique identity for every canonical Fabushi project while keeping human-readable project keys and historical task namespaces stable.

## Canonical identity model

Each project has two distinct identifiers:

- **Project ID** — global portfolio identity, format `FAB-P0001`, `FAB-P0002`, ... . This is immutable and unique across Fabushi.
- **Project Key** — short mnemonic namespace such as `TFI`, `FPG`, `FCM`, `GBF`, `MSR`. This is used by WBS/task/requirement identifiers and remains stable for human readability.

Historical values that were previously called `project_id` are retained in `legacy_project_ids`; they are aliases only and must never be reassigned to another project.

## Allocation rules

1. `projects/PORTFOLIO.json` is the authoritative allocation registry.
2. A new project MUST allocate exactly the registry's current `next_sequence` using `FAB-P%04d`.
3. The same pull request MUST:
   - add the registry entry;
   - increment `next_sequence` by one;
   - create the project folder and `PROJECT.yaml` with the same `project_id` and `project_key`.
4. Existing IDs MUST NOT be edited, swapped, compacted, recycled, or reassigned.
5. Archived, cancelled, merged, superseded, or renamed projects keep their Project ID forever. Keep the registry entry and mark status rather than deleting it.
6. Project directory rename does not change Project ID. Update `slug`/`authoritative_path` and preserve aliases/history.
7. Project split creates new Project IDs for the new independent projects; the original ID remains with the original historical project record.
8. Project merge/consolidation keeps all historical IDs registered. One project may become canonical, but other IDs are marked superseded/merged rather than reused.
9. Concurrent project creation intentionally contends on `PORTFOLIO.json`. Resolve the merge conflict by re-reading canonical `main` and reallocating the later project to the new `next_sequence`.

## Backfill rule for pre-policy projects

Existing canonical projects are numbered by the timestamp of their first formal `projects/<slug>/` project-folder commit merged to GitHub `main`. This provides deterministic, auditable ordering and avoids subjective priority-based numbering.

## Required PROJECT.yaml fields

```yaml
project_id: FAB-P0001
project_key: TFI
legacy_project_ids:
  - FABUSHI-TELEGRAM-FUSION
name: <human-readable name>
slug: <project-slug>
authoritative_path: projects/<project-slug>
```

`project_id` is the cross-project identity. `project_key` is the mnemonic namespace for internal IDs such as `TFI-GOV-002` or `MSR-103`.

## Validation and governance

CI validates:

- Project ID regex and sequence;
- uniqueness of Project IDs, project keys, slugs, and authoritative paths;
- `next_sequence == max(sequence) + 1`;
- exact parity between registry entries and canonical project folders;
- `PROJECT.yaml` identity/path consistency;
- immutable Project ID and project key for already-registered slugs when compared with the pull request base branch;
- preservation of prior registry entries, preventing silent deletion/reuse.

## External systems

Google Sheets, Drive, Calendar, Gmail, issue trackers, release systems, and other control planes must mirror the same `FAB-Pxxxx` Project ID when they represent a Fabushi project. GitHub `main`, `projects/PORTFOLIO.json`, and the project's `PROJECT.yaml` remain authoritative for repository engineering identity.
