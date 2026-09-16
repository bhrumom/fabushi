# M8-MARKET-004 — Marketplace 自动安全审核与自动上架

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-004`
- **Stage**: `M8 Mini Apps`
- **Status**: `IN_PROGRESS / PROTECTED_AUTOMERGE_DISPATCH_FIX`
- **Started**: `2026-09-16`
- **Implementation PR**: `#2653` (merged)
- **Bootstrap publication PR**: `#2654` (merged)
- **Same-PR hardening PRs**: `#2655`, `#2657`, `#2660`, `#2662` (merged)
- **Proof PRs**: `#2656`, `#2661`, `#2663` (progressively exposed and proved control-plane edges; final clean proof will be recreated after this fix)
- **Current fix branch**: `codex/tfi-market-004-automerge-dispatch-input-20260916`
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
- generated commit push 后，GitHub PR API 允许短暂处于最终一致性延迟。publisher 有界轮询到新 generated SHA；轮询期间只允许 `reviewed source SHA -> pushed generated SHA`，出现任何第三个 SHA 立即 fail closed，超时也 fail closed。
- `Explicit automerge` 的 `workflow_dispatch` 必须从 `context.payload.inputs.pr_number` 读取 workflow input，不能用 `core.getInput('pr_number')`（后者只读取 action input）。输入必须校验为正整数后才能读取 PR；非法/缺失输入 fail closed，绝不能退化为 `/pulls/0`。
- gVisor 作为后续第三方运行时动态沙箱；普通 GitHub-hosted Docker 不冒充完整 hostile-code sandbox。

## Acceptance criteria

1. 任意 `.agents/plugins/plugins/**` 或 `.agents/plugins/marketplace.json` 变更都会进入统一审核。
2. deterministic auditor 对每个插件校验目录边界、manifest 一致性、版本、runtime/MCP 描述、symlink/危险文件、明显 secrets/private keys、危险下载执行模式，并生成 immutable plugin digest。
3. 审核输出 `fabushi.marketplace.audit.v1` JSON，包含 exact GitHub source SHA、每个插件版本、digest、decision、findings。
4. Semgrep/Trivy/OSV/CodeQL + Syft/Grype 是 required security layers；critical/high finding 或 scanner failure 阻止 `CI result`。
5. public catalog + approval ledger 由 internal marketplace + plugin manifests + approved audit result 确定性生成；手工漂移会被 CI/生成器拒绝。
6. 只有当前源码 digest 与 approved ledger 相符的 plugin/version 才能进入公开 catalog；同一 approved version 源码变化必须失败并要求 version bump。
7. exact source PR head 全绿后，trusted `Marketplace Auto Publish` 自动生成 catalog/ledger，只允许这两个 generated path 被改写，并 commit/push 回同一个 source PR。
8. generated push 后必须有界等待 PR head 收敛；短暂仍返回 reviewed source SHA 只视为 eventual-consistency 延迟，任何其他 SHA 视为并发移动并立即阻断。
9. publisher 必须确认 **最终当前 PR head** 有 successful `CI result`：新生成 head 显式 dispatch CI；重试时若该 exact head 已成功则安全复用，不得因 `generator changed=false` 绕过 final-head CI。
10. final-head CI 成功后，trusted publisher 才能添加 `automerge` 授权标签并显式 dispatch 已有 `automerge.yml`；controller 必须正确解析显式 PR number，并继续执行敏感路径策略、required product gates 与 protected merge queue/merge-group。
11. fork PR 或同时修改 `scripts/` / `.github/` / `.semgrep/` 等安全发布工具的 PR 禁止 privileged write-back。
12. 审核报告和 scanner outputs 在 Actions `always()` 路径上传，目标 90 天保留。
13. 任务只有在 automerge dispatch fix protected merge、canonical-main readback、`Marketplace Auto Publish` safe-no-op smoke 与一个从最新 main 创建的真实 same-repo plugin version change 完成 write-back → final-head CI → trusted automerge → merge-group → canonical catalog readback 全链证据后才标记完成。

## Verification

- `python3 scripts/test-marketplace-security.py`
- `python3 scripts/audit-official-plugin-marketplace.py --report ...`
- `python3 scripts/generate-official-plugin-marketplace.py --check`
- `python3 scripts/check-official-plugin-marketplace.py`
- GitHub Actions exact-head / merge-group / canonical-main security runs
- bootstrap ledger/public catalog canonical-main readback
- `Marketplace Auto Publish` safe no-op on an open same-repo non-plugin PR
- clean real plugin PR must prove generated-file write-back + PR-head convergence + exact final-head CI + Explicit automerge dispatch + merge-group + canonical public catalog/approval readback.

## Current evidence

- Baseline canonical `main`: `944461ea020966dd76905c7e601d9e6c121ae4b3`.
- PR `#2653` merged the security stack through protected merge queue; post-merge canonical source SHA was `92b505a277b4104afd08ab8c5af01984fd63a6ed`.
- canonical Marketplace Security Review run `35052391204` passed deterministic policy, Semgrep CE, Trivy, Syft/Grype, CodeQL JavaScript/Python/Rust and OSV full scan.
- bootstrap PR `#2654` passed required CI/merge queue and established canonical approval records for 13 plugins.
- same-PR hardening PRs `#2655`, `#2657`, `#2660` merged; #2660 closed publisher PR-write permission and idempotent exact-final-head CI orchestration.
- PR `#2662` closed the generated-head eventual-consistency race and merged through protected merge queue as canonical `b28e5a352e4fa0f14015aa57727f9db67396a6bd`; candidate CI run `35060082620` passed.
- final-clean proof PR `#2663` was created from that exact canonical main with only three developer-authored files and no public catalog/approval edits or manual automerge authorization.
- #2663 source head `f897918025dc05be14fef624868a505c97aabb72` passed full required CI run `35060342506`.
- Marketplace Auto Publish run `35060446919` automatically resolved/re-audited #2663, generated catalog + approval ledger, committed/pushed generated head `9c38414feff5bc1a8e872a2abafc491a70bf6a00`, successfully passed the new PR-head convergence step, and dispatched final-head CI.
- final generated-head CI run `35060485369` passed deterministic policy, strict generated catalog/approval synchronization, CodeQL JS/Python/Rust, Semgrep, Trivy, OSV, Syft/Grype and final `CI result`.
- Auto Publish then successfully added the `automerge` label itself, proving the publisher permission fix. It failed only when invoking the existing protected merge controller.
- Explicit automerge run `35060637837`, job `104680018936`, shows the exact failure: the `workflow_dispatch` branch executed `Number(core.getInput('pr_number'))`, which produced `0`, then `github.rest.pulls.get` requested `/repos/bhrumom/fabushi/pulls/0` and failed 404. The dispatch itself succeeded; the controller parsed its workflow input using the wrong API.

## Blockers

- Repository-official same-repo path: merge the minimal protected automerge workflow-input parsing fix, then run one fresh end-to-end BotFather 1.0.1 proof from the new canonical main and close superseded proofs.
- Third-party fork/external repository hostile runtime dynamic execution remains a successor/non-goal because a true sandbox runner/gVisor execution plane is not currently proven in repository CI; it does not block the official same-repo pipeline acceptance target.
