# M8-MARKET-004 — Marketplace 自动安全审核与自动上架

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-004`
- **Stage**: `M8 Mini Apps`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-09-16`
- **Branch**: `codex/tfi-market-004-auto-review-publish-20260916`
- **Source requirement**: `../../source/2026-09-16-marketplace-automatic-security-review-publish.md`

## Objective

让仓库内所有官方 Mini App/插件统一走自动安全审核；审核通过后由 canonical-main privileged lane 自动生成公开 Marketplace catalog / approval ledger 并通过受保护 PR 上架。审核失败、证明缺失或 digest 漂移时 fail closed。

## Reuse / architecture decision

- 复用 `M8-MARKET-003` 的 GitHub immutable `sourceRef + sha256 + size + install` 合同，不新增 updater/installer。
- 复用 `.agents/plugins/marketplace.json` 作为官方插件登记源；公开 `.well-known/mahayana/marketplace.json` 改为确定性生成物。
- GitHub Actions 只做 orchestration；Fabushi deterministic auditor 是最小不可绕过信任根，外加 CodeQL、Semgrep CE、Trivy、OSV、SBOM/Grype 多层扫描。
- untrusted PR 审核只给 `contents: read` / `security-events: write` 等最小权限，不提供 publish token。只有 canonical `main` 才能进入生成/发布 lane。
- 自动上架不直接 push protected main：canonical-main workflow 生成 publish branch/PR，required checks 通过后启用 auto-merge/merge queue。
- gVisor 作为后续第三方运行时动态沙箱；普通 GitHub-hosted Docker 不冒充完整 hostile-code sandbox。

## Acceptance criteria

1. 任意 `.agents/plugins/plugins/**` 或 Marketplace manifest 变更都会触发统一审核。
2. deterministic auditor 对每个插件校验目录边界、manifest 一致性、版本、runtime/MCP 描述、symlink/危险文件、明显 secrets/private keys、危险下载执行模式，并生成 immutable plugin digest。
3. 审核输出 `fabushi.marketplace.audit.v1` JSON，包含 exact GitHub source SHA、每个插件版本、digest、decision、findings。
4. Semgrep/Trivy/OSV/CodeQL 在 GitHub Actions 作为额外 required security layers；critical/high security finding 阻止审核 gate。
5. public catalog 由 internal marketplace + plugin manifests + approved audit ledger 确定性生成；手工漂移会被 CI 拒绝。
6. 只有当前源码 digest 与 approved ledger 相符的 plugin/version 才能进入公开 catalog。
7. canonical `main` 审核全绿后，如果 generated public catalog / ledger 有变化，workflow 自动创建受保护 publish PR；不允许 PR-originated code 获得写权限。
8. publish PR 重新运行同一审核与 catalog reproducibility check；required checks 成功后走 auto-merge/merge queue。
9. 审核报告和 scanner outputs 在 Actions `always()` 路径上传，目标 90 天保留。
10. 任务只有在 PR protected merge、canonical-main readback、workflow 实跑及 auto-publish/无变化 readback 证据完成后才可标记完成。

## Verification

- `python3 scripts/audit-official-plugin-marketplace.py --report ...`
- `python3 scripts/generate-official-plugin-marketplace.py --check`
- existing `python3 scripts/check-official-plugin-marketplace.py`
- targeted unit fixtures for a good plugin and fail-closed secret/danger/symlink/drift cases
- GitHub Actions exact-head / merge-group / main runs
- canonical public catalog readback after generated publish PR merge

## Current evidence

- Baseline canonical `main`: `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- Existing `M8-MARKET-003` already provides immutable artifact SHA-256/size/sourceRef install contract.
- Existing `miniapp_marketplace.js` only exposes approved manifests globally; dynamic publisher submissions currently require explicit `review()` and remain unchanged/fail-closed until the ingestion worker adopts this audit protocol.

## Blockers

- None for repository-official auto review/catalog generation implementation.
- Third-party external repository hostile runtime dynamic execution remains a successor because a true sandbox runner/gVisor execution plane is not currently proven in repository CI.
