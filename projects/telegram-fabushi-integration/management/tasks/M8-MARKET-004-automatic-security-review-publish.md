# M8-MARKET-004 — Marketplace 自动安全审核与自动上架

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-004`
- **Stage**: `M8 Mini Apps`
- **Status**: `IN_PROGRESS / FINAL_CONTROL_PLANE_CLOSURE`
- **Started**: `2026-09-16`
- **Implementation PR**: `#2653` (merged)
- **Bootstrap publication PR**: `#2654` (merged)
- **Same-PR hardening PRs**: `#2655`, `#2657` (merged)
- **End-to-end proof PR**: `#2656` (open; generated listing already written back automatically)
- **Final closure branch**: `codex/tfi-market-004-final-control-plane-20260916`
- **Source requirement**: `../../source/2026-09-16-marketplace-automatic-security-review-publish.md`

## Objective

让仓库内所有官方 Mini App/插件统一走自动安全审核；审核通过后由 trusted default-branch workflow 自动把公开 Marketplace catalog / approval ledger 生成并写回同一个插件源码 PR，再经过 required CI + protected merge queue 一次性合并上架。审核失败、证明缺失或 digest 漂移时 fail closed。

## Reuse / architecture decision

- 复用 `M8-MARKET-003` 的 GitHub immutable `sourceRef + sha256 + size + install` 合同，不新增 updater/installer。
- 复用 `.agents/plugins/marketplace.json` 作为官方插件登记源；公开 `.well-known/mahayana/marketplace.json` 与 `marketplace-approvals.json` 是确定性生成物。
- GitHub Actions 只做 orchestration；Fabushi deterministic auditor 是最小不可绕过信任根，外加 CodeQL、Semgrep CE、Trivy、OSV、Syft/Grype 多层扫描。
- untrusted PR 审核只给 read/security-events 最小权限；write-capable `Marketplace Auto Publish` 只由 default-branch `workflow_run` 在 exact-head `CI` success 后运行，并拒绝 fork PR / 安全发布工具同时变更的 PR。
- 不启用 repository-wide “GitHub Actions 可创建/批准 PR” 权限、不引入 PAT，也不直接 push protected `main`。生成文件写回现有 same-repo source PR；最终 PR head 必须拥有 exact-head successful `CI`，然后才允许 trusted publisher 添加现有 `automerge` 授权标签并显式调用仓库已有 `automerge.yml`，最终仍由 merge queue/merge-group 决定是否进入 main。
- trusted publisher 仅增加 PR 标签所需的 job-scoped `pull-requests: write`；不授予 fork PR write-back，不新增长期凭据。
- final-head CI 采用幂等 ensure 语义：如果当前最终 head 已有 successful `CI` 则复用；否则显式 `workflow_dispatch` 并等待 exact SHA success。这样生成后失败/重试不会跳过最终验证，也不会形成 CI→publisher→CI 无限循环。
- gVisor 作为后续第三方运行时动态沙箱；普通 GitHub-hosted Docker 不冒充完整 hostile-code sandbox。

## Acceptance criteria

1. 任意 `.agents/plugins/plugins/**` 或 `.agents/plugins/marketplace.json` 变更都会进入统一审核。
2. deterministic auditor 对每个插件校验目录边界、manifest 一致性、版本、runtime/MCP 描述、symlink/危险文件、明显 secrets/private keys、危险下载执行模式，并生成 immutable plugin digest。
3. 审核输出 `fabushi.marketplace.audit.v1` JSON，包含 exact GitHub source SHA、每个插件版本、digest、decision、findings。
4. Semgrep/Trivy/OSV/CodeQL + Syft/Grype 是 required security layers；critical/high finding 或 scanner failure 阻止 `CI result`。
5. public catalog + approval ledger 由 internal marketplace + plugin manifests + approved audit result 确定性生成；手工漂移会被 CI/生成器拒绝。
6. 只有当前源码 digest 与 approved ledger 相符的 plugin/version 才能进入公开 catalog；同一 approved version 源码变化必须失败并要求 version bump。
7. exact source PR head 全绿后，trusted `Marketplace Auto Publish` 自动生成 catalog/ledger，只允许这两个 generated path 被改写，并 commit/push 回同一个 source PR。
8. publisher 必须确认 **最终当前 PR head** 有 successful `CI result`：新生成 head 显式 dispatch CI；重试时若该 exact head 已成功则安全复用，不得因 `generator changed=false` 绕过 final-head CI。
9. final-head CI 成功后，trusted publisher 才能添加 `automerge` 授权标签并显式 dispatch 已有 `automerge.yml`；敏感路径策略和 protected merge queue/merge-group 继续有效。
10. fork PR 或同时修改 `scripts/` / `.github/` / `.semgrep/` 等安全发布工具的 PR 禁止 privileged write-back。
11. 审核报告和 scanner outputs 在 Actions `always()` 路径上传，目标 90 天保留。
12. 任务只有在 final control-plane PR protected merge、canonical-main readback、`Marketplace Auto Publish` manual safe-no-op smoke 与真实 same-repo plugin version change 的 write-back → final-head CI → automerge → merge-group → canonical catalog readback 全链证据完成后才标记完成。

## Verification

- `python3 scripts/test-marketplace-security.py`
- `python3 scripts/audit-official-plugin-marketplace.py --report ...`
- `python3 scripts/generate-official-plugin-marketplace.py --check`
- `python3 scripts/check-official-plugin-marketplace.py`
- GitHub Actions exact-head / merge-group / canonical-main security runs
- bootstrap ledger/public catalog canonical-main readback
- `Marketplace Auto Publish` workflow-dispatch smoke on an open same-repo non-plugin PR (non-plugin PR => safe no-op)
- real plugin PR must prove generated-file write-back + exact final-head CI + Explicit automerge dispatch + merge-group + canonical public catalog/approval readback.

## Current evidence

- Baseline canonical `main`: `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- PR `#2653` merged the security stack through protected merge queue; post-merge canonical source SHA was `92b505a277b4104afd08ab8c5af01984fd63a6ed`.
- canonical Marketplace Security Review run `35052391204` passed deterministic policy, Semgrep CE, Trivy, Syft/Grype, CodeQL JavaScript/Python/Rust and OSV full scan.
- first auto-publish run `35052478261` successfully re-audited, generated and pushed branch `automation/marketplace-publish-92b505a277b4`, but repo-level GitHub setting blocked `GITHUB_TOKEN` from creating a second PR.
- bootstrap PR `#2654` was therefore created from that exact generated branch, passed required CI/merge queue, and merged as canonical `efea16b40590ce60ec22474dbb82464bc7c542eb`.
- canonical `marketplace-approvals.json` contains 13 `approved` plugin/version/digest records.
- same-PR hardening PRs `#2655` and `#2657` are merged; current canonical main before this closure round is `a135a79baa9a0280004964e8603112f66b1fd86f`.
- BotFather proof PR `#2656` first source head passed full CI. `Marketplace Auto Publish` run `35057442036` then successfully resolved/re-audited the exact PR, generated catalog/approval ledger, committed and pushed the generated files back into the same PR. It failed only at `Add Marketplace automerge authorization label`; generated-head CI and protected automerge were therefore skipped in that run.
- GitHub official workflow-permissions documentation states PR labeling requires `pull-requests: write`; current publisher declares only `pull-requests: read`. GitHub also documents that `workflow_dispatch` initiated with `GITHUB_TOKEN` is an explicit exception that does trigger another workflow, so exact-head CI dispatch is a supported PAT-free control path.

## Blockers

- Repository-official same-repo path: final control-plane permission/idempotent-final-CI patch must merge, then the real plugin proof must complete through merge-group and canonical readback.
- Third-party fork/external repository hostile runtime dynamic execution remains a successor because a true sandbox runner/gVisor execution plane is not currently proven in repository CI.
