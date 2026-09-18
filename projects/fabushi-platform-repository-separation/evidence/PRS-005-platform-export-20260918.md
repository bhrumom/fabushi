# PRS-005 — Platform export evidence

- Project: `FAB-P0013` / `PRS`
- Task: `PRS-005`
- Execution date: `2026-09-18` (Asia/Shanghai)
- Source repository: `https://github.com/bhrumom/fabushi`
- Fixed source SHA: `7851b689d2fe3fc3893cd9f4363899cc4a03e83b`
- Workflow: [`Platform repository export`](https://github.com/bhrumom/fabushi/actions/workflows/platform-repository-export.yml)
- Export method: GitHub-hosted fresh mirror + `git-filter-repo`
- Secret handling: the existing `OFFICIAL_SITE_RELEASE_PAT` was used only by the explicit `dry_run=false`
  push step; no secret value was read into this record or copied to any target repository.

## Formal export readback

All runs below completed with `success`, used `dry_run=false`, pushed `refs/heads/main`, and uploaded a
90-day evidence artifact. `path entries` is the line count of the generated target path manifest, including
the generated `README.md` and `MIGRATION_SOURCE.md`. The target fsck report was empty for each formal run.

| Target | Repository | Workflow run | Source SHA | Target `main` SHA | Path entries | Artifact | Rollback ref |
| --- | --- | --- | --- | --- | ---: | --- | --- |
| Core | [`fabushi-platform-core`](https://github.com/bhrumom/fabushi-platform-core) | [35306250392](https://github.com/bhrumom/fabushi/actions/runs/35306250392) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `30d7df96a18957be040889af3c0f85861bee8da7` | 5,419 | `platform-export-core-35306250392` | `refs/backup/prs-bootstrap-20260918` |
| CLI | [`fabushi-cli`](https://github.com/bhrumom/fabushi-cli) | [35306247989](https://github.com/bhrumom/fabushi/actions/runs/35306247989) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `f92827f04ea60133f35878f08a92bd55827954f6` | 33 | `platform-export-cli-35306247989` | `refs/backup/prs-bootstrap-20260918` |
| Web | [`fabushi-web`](https://github.com/bhrumom/fabushi-web) | [35307009976](https://github.com/bhrumom/fabushi/actions/runs/35307009976) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `08bf889c4f6a492868a9ee6d39a1604e4ca35de2` | 509 | `platform-export-web-35307009976` | `refs/backup/prs-bootstrap-20260918` |
| Desktop | [`fabushi-desktop`](https://github.com/bhrumom/fabushi-desktop) | [35307011937](https://github.com/bhrumom/fabushi/actions/runs/35307011937) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `12d4aadb4a93a1413ece44aba987162e90b31229` | 121 | `platform-export-desktop-35307011937` | `refs/backup/prs-bootstrap-20260918` |
| Android | [`fabushi-android`](https://github.com/bhrumom/fabushi-android) | [35307015684](https://github.com/bhrumom/fabushi/actions/runs/35307015684) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `efa3e7a327865c9ae3b02545bc6b43aeaa75dd9e` | 75 | `platform-export-android-35307015684` | `refs/backup/prs-bootstrap-20260918` |
| iOS | [`fabushi-ios`](https://github.com/bhrumom/fabushi-ios) | [35307019753](https://github.com/bhrumom/fabushi/actions/runs/35307019753) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `ea0e6c017ac381c3691aa4da84b7ba159077f5a4` | 45 | `platform-export-ios-35307019753` | `refs/backup/prs-bootstrap-20260918` |
| WeChat | [`fabushi-wechat`](https://github.com/bhrumom/fabushi-wechat) | [35307022288](https://github.com/bhrumom/fabushi/actions/runs/35307022288) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `9dff22b194a7cb1ed73cae810294f2662a51a750` | 50 | `platform-export-wechat-35307022288` | `refs/backup/prs-bootstrap-20260918` |
| Browser | [`fabushi-chrome-extension`](https://github.com/bhrumom/fabushi-chrome-extension) | [35307025530](https://github.com/bhrumom/fabushi/actions/runs/35307025530) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `fd339aba378f36e71550d3b98fa44a9df4a2a1f0` | 31 | `platform-export-browser-35307025530` | `refs/backup/prs-bootstrap-20260918` |
| Backend | [`fabushi-backend`](https://github.com/bhrumom/fabushi-backend) | [35307027606](https://github.com/bhrumom/fabushi/actions/runs/35307027606) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `91b6acce334c1819b5debfe6503c2b9cf67f48a2` | 309 | `platform-export-backend-35307027606` | `refs/backup/prs-bootstrap-20260918` |
| Forum | [`fabushi-forum`](https://github.com/bhrumom/fabushi-forum) | [35307030753](https://github.com/bhrumom/fabushi/actions/runs/35307030753) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `d356508436e4294783e4f6c4c99b754f2fc06a80` | 46 | `platform-export-forum-35307030753` | `refs/backup/prs-bootstrap-20260918` |
| Commerce | [`fabushi-commerce`](https://github.com/bhrumom/fabushi-commerce) | [35307032973](https://github.com/bhrumom/fabushi/actions/runs/35307032973) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `6fbab6772770dabc4182fd9f0e453d7415b73ab3` | 15 | `platform-export-commerce-35307032973` | `refs/backup/prs-bootstrap-20260918` |
| Marketplace | [`fabushi-marketplace`](https://github.com/bhrumom/fabushi-marketplace) | [35307035002](https://github.com/bhrumom/fabushi/actions/runs/35307035002) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `636dc11d86062cc544083ced167977353d0c5260` | 14 | `platform-export-marketplace-35307035002` | `refs/backup/prs-bootstrap-20260918` |
| Governance | [`fabushi-governance`](https://github.com/bhrumom/fabushi-governance) | [35307037007](https://github.com/bhrumom/fabushi/actions/runs/35307037007) | `7851b689d2fe3fc3893cd9f4363899cc4a03e83b` | `a4ff25b9e4ae8e0375f2972a68a0c98cd04bea01` | 1,359 | `platform-export-governance-35307037007` | `refs/backup/prs-bootstrap-20260918` |

## Boundary readback

- `fabushi-cli` contains the CLI/TUI/harness/test-driver roots only; it is not included in the Core export.
- `fabushi-platform-core` contains the shared runtime/contracts roots and excludes the CLI-specific crates.
- Each target `MIGRATION_SOURCE.md` records source repository `bhrumom/fabushi`, the full source SHA above,
  its target boundary, exact source roots, and `FAB-P0013 / PRS`.
- The existing `bhrumom/fabushi-chatgpt-auto-confirm-userscript` repository was reused and was not copied
  into the Browser target.

## Remaining gates

This evidence proves repository materialization and export integrity only. It does not claim that the target
repositories already have independent branch protection, CODEOWNERS, CI, package builds, simulated-user E2E,
Release assets, updater/store wiring, or production cutover. Those remain tracked under PRS-004/006/007/008.
