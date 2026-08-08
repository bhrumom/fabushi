# v12 原子执行任务与自动验收矩阵

任务：`mahayana-marketplace-cloudflare-20260730`

本文件把 T01-T08 拆成可独立验收、可由 GitHub Actions 自动判定的原子任务。任务完成状态不得靠主观汇报，必须有对应代码、测试、Check、commit/run 证据。

## 统一完成规则

每个原子任务必须具备：

- `Task ID`；
- 明确实现边界；
- 一个稳定的 GitHub Actions required check 名称；
- 自动断言/测试命令；
- 真实 evidence：commit SHA、workflow run/check URL、必要的仓库/API/Release/市场结果；
- 状态只允许：`not-started`、`in-progress`、`blocked`、`passed`、`failed`；
- 只有 check conclusion=`success` 且证据满足业务验收时才可记为 `passed`；
- Txx 进度 = `passed 原子任务数 / 必需原子任务总数 * 100%`；
- 任一必需任务不是 `passed`，父 Txx 不得标记完成；
- 所有 T01-T08 均为 100% 后，本项目才允许报告完成。

建议统一 workflow：`.github/workflows/mahayana-v12-atomic-acceptance.yml`，每个 job 名称与下方 required check 完全一致，避免 ruleset 上下文名称漂移。

---

## T01 架构与源码所有权边界

### T01.1 身份模型落库
- 实现：数据模型明确区分 `author`、`sourceHost`、`repositoryOwner`、`publisher`、`officialStatus`、`deploymentTarget`。
- Required check：`v12 / T01.1 identity-schema`
- 自动断言：schema/migration/serialization round-trip；旧数据升级不丢失 source identity。
- 通过标准：官方 App、法布施托管用户 App、用户自有 GitHub App 三类 fixture 都能得到不同且正确的身份组合。

### T01.2 用户托管组织与官方组织隔离
- 实现：`bhrumom` 仅作为官方代码组织；用户托管目标来自独立 `managedUserAppsOwner` 配置，不得硬编码到 `bhrumom`。
- Required check：`v12 / T01.2 managed-org-boundary`
- 自动断言：official repo 可在 `bhrumom`；managed user repo 若 owner=`bhrumom` 必须失败；配置缺失时 fail closed。
- 通过标准：测试证明用户托管仓库不能进入官方源码组织信任域。

### T01.3 市场身份展示
- 实现：市场/详情页展示作者、源码托管方、GitHub owner/repo、publisher、`官方/用户作品` 标识。
- Required check：`v12 / T01.3 marketplace-source-labels`
- 自动断言：UI/component/API contract snapshot 覆盖 official、managed-hosted、user-github 三类。
- 通过标准：法布施托管用户 App 不得显示为“法布施官方应用”。

### T01.4 信任边界负向测试
- 实现：用户托管仓库不能获得官方发布身份、官方 badge、官方 signing/OIDC trust。
- Required check：`v12 / T01.4 trust-boundary-negative`
- 自动断言：伪造 publisher/officialStatus/owner 或复用官方 plugin identity 必须被拒绝。
- 通过标准：至少覆盖 API、manifest validation、release policy 三层负向测试。

---

## T02 本地 Workspace 与发布状态机

### T02.1 本地生成、持久化、离线重开
- 实现：聊天生成代码先写本地 workspace，不依赖 GitHub；支持重开、继续修改、本地运行。
- Required check：`v12 / T02.1 local-workspace-offline`
- 自动断言：禁网 fixture 下 create → persist → reopen → edit → run 全链成功。
- 通过标准：无 GitHub connector/网络仍能完成完整本地循环。

### T02.2 安全发布快照
- 实现：发布前生成 deterministic source snapshot/tree hash，过滤 `.env`、Token、Cookie、数据库、聊天记录、缓存、构建目录。
- Required check：`v12 / T02.2 safe-source-snapshot`
- 自动断言：secret fixtures 必须被阻断；相同源码产生相同 tree hash；服务端可重算。
- 通过标准：敏感文件零泄漏，hash 可复核。

### T02.3 发布状态机
- 实现：`local-only → source-hosted → build-passed → released → marketplace-listed → installable`，失败状态显式记录。
- Required check：`v12 / T02.3 deployment-state-machine`
- 自动断言：合法转移通过；跳级、回退越权、把 source push 当 release 等非法转移失败。
- 通过标准：每个 UI/API 状态与后端事实一一对应。

### T02.4 失败与远程分叉保护
- 实现：上线失败保留本地项目；远程已有未知提交时禁止强推覆盖，先 compare/fetch/merge/rebase。
- Required check：`v12 / T02.4 sync-and-rollback-safety`
- 自动断言：模拟 API/GitHub 失败和远端 diverged history；本地工作区无损，force push 路径被拒绝。
- 通过标准：失败可重试且不产生数据丢失。

---

## T03 官方托管 GitHub 控制面

### T03.1 GitHub App 最小权限控制面
- 实现：官方托管只使用 GitHub App installation token/短期凭证；禁止组织 PAT 下发客户端。
- Required check：`v12 / T03.1 github-app-control-plane`
- 自动断言：配置扫描和集成测试证明客户端 payload/log/db 无 org PAT；token scope 为最小仓库权限。
- 通过标准：无 GitHub 账号的法布施用户可触发可信后端仓库创建。

### T03.2 幂等建仓与命名隐私
- 实现：`deploymentId/idempotencyKey` 保证重复请求只产生一个 repo；repo name 不含邮箱/手机号/真实姓名等 PII。
- Required check：`v12 / T03.2 idempotent-repo-create`
- 自动断言：并发/重试 fixture 返回同一 repositoryId；PII 命名样本被拒绝/脱敏。
- 通过标准：不存在重复仓库和明显 PII 泄露。

### T03.3 首次 push 与来源绑定
- 实现：本地安全快照写入 managed repo，记录 repositoryId/defaultBranch/commit/treeHash。
- Required check：`v12 / T03.3 initial-source-push`
- 自动断言：远端文件清单/hash 与本地发布快照完全一致；额外文件或缺失文件失败。
- 通过标准：真实测试 repo 可复核 exact commit/tree。

### T03.4 仓库策略 bootstrap
- 实现：创建仓库后配置标准模板、CODEOWNERS、untrusted PR CI、trusted release、ruleset、审计事件。
- Required check：`v12 / T03.4 managed-repo-bootstrap`
- 自动断言：读取真实 repo rulesets/workflows/CODEOWNERS；缺任一保护即失败。
- 通过标准：managed repo 达到与正式 MCP App 相同的最小供应链安全基线。

---

## T04 用户 GitHub 连接器与凭证隔离

### T04.1 provider/actor/transport 分层
- 实现：`provider=github`，`actor=user|fabushi-service`，`transport=github-mcp|github-app-api`；不得把 MCP 当 provider。
- Required check：`v12 / T04.1 github-actor-transport-model`
- 自动断言：serialization/API contract 覆盖两条部署路径。
- 通过标准：更换 MCP 工具实现不改变 repository identity/provider 数据模型。

### T04.2 用户显式选择 owner/repository
- 实现：首次部署到“我的 GitHub”必须明确选择 owner/repo；多组织权限时不得猜测。
- Required check：`v12 / T04.2 explicit-user-target`
- 自动断言：多 owner fixture 未提供选择时 API/UI 必须阻断；选择后才能创建/推送。
- 通过标准：不存在静默发布到错误账号/组织。

### T04.3 GitHub connector 凭证零落地
- 实现：用户 access/refresh token、connector secret 不进入 Fabushi API、日志、DB、analytics、repo。
- Required check：`v12 / T04.3 connector-secret-isolation`
- 自动断言：集成测试抓取请求/日志/持久化快照并扫描 token canary；发现即失败。
- 通过标准：Fabushi 只保存 repositoryId/repo/commit/treeHash 等非敏感元数据。

### T04.4 用户仓库真实发布与断连降级
- 实现：通过 GitHub 官方连接器/MCP 创建/更新真实用户测试仓库；连接断开时仍保留本地项目并可改走官方托管。
- Required check：`v12 / T04.4 user-github-e2e`
- 自动断言：真实 repo commit 可读取；断连后本地运行和 target switch 正常。
- 通过标准：用户 GitHub 路径不依赖 Fabushi 保存长期 GitHub 凭证。

---

## T05 可信构建与正式发布供应链

### T05.1 不受信任 PR CI
- 实现：Fork PR 仅 `pull_request`、只读 `GITHUB_TOKEN`、无 Secret、隔离 runner；禁止特权 `pull_request_target` 执行 Fork 代码。
- Required check：`v12 / T05.1 untrusted-pr-boundary`
- 自动断言：workflow policy lint + 恶意 PR fixture 尝试读取 Secret/写 repo 必须失败。
- 通过标准：PR 只能测试，不能发布正式构件。

### T05.2 Trusted Builder 与 OIDC
- 实现：正式发布仅受保护 main/tag/release → trusted reusable workflow → OIDC；用户源码仓库不能控制生产信任根。
- Required check：`v12 / T05.2 trusted-builder-oidc`
- 自动断言：非受保护 ref、Fork、普通 PR 触发 publish 必须拒绝；可信 ref 获取预期 OIDC claims。
- 通过标准：长期 cloud/marketplace signing secret 不作为普通 repo Secret 使用。

### T05.3 SBOM/Attestation/Provenance 同 commit
- 实现：common/native-*/web-wasm、SBOM、attestation、release manifest 全绑定同一 source commit/tree。
- Required check：`v12 / T05.3 provenance-consistency`
- 自动断言：下载 release artifacts 后校验 digest、provenance subject、source SHA、manifest graph；任一不一致失败。
- 通过标准：每个正式构件都可追溯至精确 commit/workflow run。

### T05.4 恶意源码不可越权发布
- 实现：恶意 managed repo/Fork 无法修改 central signing/release policy、污染 cache 或生成被市场接受的正式构件。
- Required check：`v12 / T05.4 malicious-source-release-negative`
- 自动断言：攻击 fixtures 覆盖 workflow overwrite、cache poisoning、fake manifest、plugin ID reuse。
- 通过标准：全部攻击被拒绝且无可信发布副作用。

---

## T06 托管仓库接管、迁移与退出机制

### T06.1 接管资格与明确确认
- 实现：用户连接 GitHub 后可发起“转移到我的 GitHub”；展示目标 owner、权限、可迁移内容与不可逆影响并再次确认。
- Required check：`v12 / T06.1 takeover-eligibility`
- 自动断言：无写权限/目标冲突/未确认时拒绝；满足条件时生成 transfer plan。
- 通过标准：不存在静默所有权迁移。

### T06.2 Managed → User GitHub 真实迁移
- 实现：执行真实 transfer 或等价受控 migration，保留 Git history，尽可能保留 Issues/PR/Releases；记录迁移方式。
- Required check：`v12 / T06.2 managed-to-user-migration`
- 自动断言：迁移前后 commit graph/default branch/source files 一致；目标 repositoryId/owner 更新。
- 通过标准：真实测试项目可从 managed owner 迁移到用户测试 GitHub。

### T06.3 Lineage 与市场来源更新
- 实现：市场更新 repository identity/lineage/host history，旧链接有明确迁移状态，不把用户接管后的 repo 继续标作平台所有。
- Required check：`v12 / T06.3 migration-lineage`
- 自动断言：API/market fixtures 验证 before/after identities 与 source commit 连续性。
- 通过标准：用户能证明作品来源连续且 ownership/hosting 状态准确。

### T06.4 失败回滚与非破坏退出
- 实现：迁移中断/权限变化/目标冲突时不得删除原 repo 或本地 workspace；可安全重试。
- Required check：`v12 / T06.4 migration-rollback`
- 自动断言：在多个迁移阶段注入失败，验证至少存在一个完整可用源码副本且 deployment record 可恢复。
- 通过标准：无数据丢失、无 orphaned ownership 状态。

---

## T07 规模治理、Actions 安全与成本控制

### T07.1 Managed Org 权限与 Actions 策略
- 实现：独立 managed org/repo 默认权限、Actions allowlist/reusable workflow、Fork policy、branch/tag ruleset 标准化。
- Required check：`v12 / T07.1 managed-org-policy`
- 自动断言：读取真实测试组织/仓库策略并与 policy-as-code 比对。
- 通过标准：用户源码不能获得组织管理权限或 production environment 权限。

### T07.2 配额、滥用与速率限制
- 实现：每用户 repo/build/storage/rate quota、abuse 检测、恶意批量建仓/构建防护。
- Required check：`v12 / T07.2 quota-and-abuse`
- 自动断言：并发超额、重复构建、异常仓库创建 fixtures 被限流；正常用户不误伤。
- 通过标准：达到配额只阻止远程动作，不损坏本地源码。

### T07.3 成本归集与预算护栏
- 实现：按 user/project/deployment 记录 GitHub Actions minutes、artifact/storage 等可得成本指标，支持预算阈值。
- Required check：`v12 / T07.3 cost-accounting`
- 自动断言：模拟 usage events 后账单聚合与项目归属准确；超阈值进入受控状态。
- 通过标准：可回答“哪个项目消耗了多少托管/构建资源”。

### T07.4 生命周期、归档、删除与审计
- 实现：private/public policy、inactive archive、删除/恢复窗口、账号删除与 repo 删除解耦、完整 audit trail。
- Required check：`v12 / T07.4 lifecycle-audit`
- 自动断言：archive/delete/restore fixtures + audit immutable event assertions。
- 通过标准：删除法布施账号不得静默删除用户 GitHub repo；敏感操作可审计。

---

## T08 真实双路径 E2E 与市场验收

### T08.1 无 GitHub 用户完整链路
- 实现：新用户仅登录 Fabushi → AI 生成 → 本地保存/运行 → managed repo → trusted Release → 市场 → 安装。
- Required check：`v12 / T08.1 managed-user-full-e2e`
- 自动断言：使用真实测试账号、真实 repo、真实 workflow/release/market response。
- 通过标准：用户全程不需要 GitHub 账号仍可完成上线与安装。

### T08.2 用户自己的 GitHub 完整链路
- 实现：同一本地项目通过 GitHub connector/MCP 明确发布到用户测试 GitHub → Release/市场/安装。
- Required check：`v12 / T08.2 user-github-full-e2e`
- 自动断言：真实 repositoryId/commit/tree/release 可复核，Fabushi 无 connector secret。
- 通过标准：所有权和 repository owner 明确属于用户。

### T08.3 托管项目接管链路
- 实现：T08.1 产生的 managed project 后续迁移到用户 GitHub，再继续构建/发布新版本。
- Required check：`v12 / T08.3 takeover-full-e2e`
- 自动断言：迁移前后 history/lineage/market source/version upgrade 连续。
- 通过标准：平台托管不存在不可退出锁定。

### T08.4 多平台构件与本地运行矩阵
- 实现：同一版本验证 macOS/Windows/Linux native 与 iOS/Android/Web/PWA web-wasm 选择、下载、启动。
- Required check：`v12 / T08.4 platform-install-matrix`
- 自动断言：现有平台测试矩阵/设备或模拟器 E2E；每个平台只取最小兼容构件。
- 通过标准：各平台运行相同 Tool Contract/插件版本。

### T08.5 供应链一致性总校验
- 实现：最终 release 的 repositoryId/source commit/tree hash/manifest/artifact digest/SBOM/attestation/market record/install receipt 全链一致。
- Required check：`v12 / T08.5 end-to-end-provenance`
- 自动断言：统一 verifier 从 GitHub/Release/market/install evidence 重建并比较 identity graph。
- 通过标准：任意一个 SHA/digest/identity 不一致都失败。

### T08.6 最终安全与回归门禁
- 实现：运行 T01-T08 required checks + 恶意 Fork/Secret/权限/迁移失败/远程分叉回归套件。
- Required check：`v12 / T08.6 final-project-gate`
- 自动断言：聚合所有必需 check；禁止 skip/allow-failure 伪通过。
- 通过标准：T01-T08 全部原子任务 `passed`，项目进度自动计算为 100%。

---

## Calendar / Drive 进度同步协议

Google Calendar 中每个原子任务使用稳定标题：`☐ TASK Txx.n <short title>`。当且仅当对应 required check 成功且业务证据满足本文件标准后，更新为 `☑ TASK Txx.n <short title>`，并在描述写入 commit SHA、workflow run/check URL、证据与完成时间。

父阶段 Calendar 条目 `Txx` 的进度必须按本文件必需任务数量自动计算；不得手动声称 100%。

Google Drive 中：
- 权威任务文件 v12 保存产品目标与治理边界；
- T01-T08 文件保存阶段上下文与逐项证据；
- Calendar 保存当前状态、计划日期与完成可视化；
- GitHub 保存代码和可验证工程事实。
