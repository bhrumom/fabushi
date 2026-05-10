# Fabushi 持续交付主控运行手册

本文档把仓库当前已经在执行的主控代理式持续交付流程沉淀为可审阅、可复用、可交接的仓库资产，避免发布闭环只存在于临时上下文里。

## 目标

主控的默认目标不是“汇报现状”，而是把 `PR -> main -> CI -> CD -> GitHub Release -> TestFlight` 这条链路持续推进到明确结果。

明确结果至少应满足以下之一：

- PR 已合并，且合并后的主线检查全部完成
- mainline CD 已恢复并拿到确定成功或确定失败的根因
- GitHub Release 已生成，相关发布资产可核对
- TestFlight 上传结果已被仓库内证据确认
- 若暂时无法继续，阻塞点、缺失权限和恢复后的下一步已经被精确记录

## 固定工位

### 1. 发布闭环工位

负责：

- GitHub Actions 主线 CI / CD
- 构建、打包、签名、发布
- GitHub Release
- TestFlight 上传与验证

默认要求：

- 先修首个确定性红灯，不跳过根因
- 不把“某一步绿了”当作整条链路已恢复
- 对影响发布链路的 workflow、脚本、迁移和门禁优先做第一性原理修复

### 2. PR 推进工位

负责：

- open PR
- review feedback
- ready for review / merge queue / auto-merge
- 合并后回追主线结果

默认要求：

- 默认用分支和 PR 推进，而不是直改主分支
- PR 描述里说明为什么改、改了什么、如何验证、如何防复发
- PR 合并后仍需继续回追 mainline CI / CD / Release / TestFlight

### Merge Queue 重叠改动处理规则

当多个 open PR 同时修改同一组文件、同一条用户路径或同一个回归主题时，不要把它们当成彼此独立的绿灯直接一起送进 merge queue。

默认处理方式：

- 先判断谁是主阻塞修复，谁是非阻塞补强或体验优化
- 如果后者可能覆盖前者的文件或行为，就先暂停后者的自动推进，再等待前者落主线
- 前一个 PR 合入后，再让后一个 PR 基于最新 `main` 重新确认差异、checks 和合并顺序
- 在 PR 线程或相关 issue 中明确记录这种顺序安排，避免后续巡检误把“都在排队”当成低风险状态

### Queue-only 仓库合并推进规则

当 direct merge 被仓库规则拒绝，并明确提示 `Changes must be made through the merge queue` 时，默认按“queue 是当前唯一剩余主线 gate”处理，而不是把 head checks 已绿误判成已经完成。

默认处理方式：

- 立即切换到 `auto-merge` 或等效 merge queue 路径，不让 PR 停在“绿了但没人继续推”的状态
- 在 PR 线程或相关 issue 里明确记录：当前已无代码或评审阻塞，剩余 gate 是 merge queue 本身
- 对 queue 状态的判断优先以 PR 页面、merge queue 事件和后续 mainline 结果为准，不把“曾经 enable auto-merge”本身当成完成证据
- 对“历史 head 曾经绿过”和“当前 head 已满足必需门禁”要分开判断，避免拿旧提交的绿灯误替代最新提交的 queue 准入条件
- 在 PR 真正 `merged` 之前，不关闭对应修复 issue，也不宣称问题已经进入主线
- 等待 queue 外部结果期间，立即切去其他工位推进事项或新的小步升级；一旦 queue 出现 merge / fail 新信号，再立刻切回
- PR 真正 merged 后，继续按 `main -> CI -> CD -> GitHub Release -> TestFlight` 顺序复核，而不是把 queue 放行为最终终点

### 必需检查缺口与无 Head Checks PR 规则

对文档、运行手册、提示词映射或其他轻量改动 PR，可能会出现 `head SHA` 没有关联 workflow runs、combined status 为空的情况。主控不能只看“有没有红灯”，还要先判断这在当前仓库规则下到底是不是允许状态。

默认处理方式：

- 先区分这是“本来就不会触发检查”，还是“按仓库保护规则本应触发却没有触发”
- 如果仓库保护规则明确要求某个必需检查，例如 `CI result`，但当前 head 完全没有 workflow run 或 status 记录，就把它视为真实的触发/覆盖缺口，而不是普通等待
- 进入这类缺口时，优先修复 workflow 触发条件、分支基线或 PR 形态；必要时通过基于最新 `main` 的替代分支和替代 PR 重新挂载必需门禁
- 只有在仓库规则确实允许该类 PR 无额外检查时，才可继续按 review / auto-merge / merge queue 路径推进
- 这类 PR 在真正 `merged` 前，仍然属于等待中的 PR 事项，不能因为 checks 为空就误判成失败，也不能因为没有红灯就误判成已闭环

### Draft PR 无检查收口规则

当一条 draft PR 的当前 `head SHA` 既没有 workflow runs，也没有 combined status，而且工具链或接口又无法稳定把它转成 ready for review 时，不要把它当成普通等待位长期悬空。

默认处理方式：

- 先记录旧 draft 的 `head SHA`、缺失的必需检查名，以及“当前没有 runs / status”这个事实
- 如果仓库规则要求 `CI result` 之类的必需门禁，而当前工具又无法直接把 draft 转正，就关闭旧 draft，并基于同一 `head branch` 立即重开一条 ready PR
- 把这条新 ready PR 视为“重新挂载必需门禁”的动作，而不是重复开新需求；PR 描述或评论里要说明替代原因
- 只有当新 ready PR 也继续没有 head checks 时，才进一步把问题升级为真实 workflow 触发缺口继续追
- 旧 draft 与替代 ready PR 之间的关系要在评论、运行手册或主控记录里留痕，避免后续巡检误把旧 draft 继续当成活跃主线

### 3. Issue 治理工位

负责：

- 用户反馈
- 自动化 failure issue
- 交付阻塞的根因归并
- 回归防护

默认要求：

- 优先处理会挡住合并、发布或真实用户路径的 issue
- 能归并到同一根因时，不要只按表面症状逐条打补丁
- 修复后补充影响范围、验证路径和后续观察点

### 4. 分支收口工位

负责：

- 已开分支但未闭环的补丁
- 缺失验证补齐
- merge queue 前后收尾

默认要求：

- 分支工作只有在主线交付链路闭环后才算完成
- 已开 PR 或 checks success 不是终点

### 5. 等待窗口迭代工位

当 CI / CD / release / 外部上传在跑时，不空等，立即切去推进其他事项；如果其他事项也都在等待，则继续推进至少一项新的高价值小步升级。

这类升级应满足：

- 可审阅
- 可验证
- 可回滚
- 不牺牲当前发布闭环

默认还应明确两条调度纪律：

- “等待”不是暂停信号，而是切工位信号
- 只要关键事项都在等外部结果，就必须继续推进新的小步升级或仓库同步事项

### 6. 仓库同步工位

凡是长期有效、应被复用、应被版本管理的规则，都要同步回仓库，不只保留在 Memory 或一次性调度上下文中。

优先同步的对象包括：

- 主控调度规则
- 发布门禁说明
- 运行手册
- 提示词映射说明
- 自动化 guardrail 约束

## Fabushi 仓库特定门禁

### D1 迁移规则

Fabushi 当前主线发布依赖：

- `fabushi/web/migrations/`
- `.github/workflows/deploy-production.yml`
- `.github/scripts/check-publish-cd-release.sh`

因此涉及 Worker schema 的改动必须满足：

- 需要被主线 deploy 自动执行的 D1 变更，必须放入 `fabushi/web/migrations/`
- 不能把生产需要的 schema 只留在一次性脚本、实验 SQL 或仓库其他目录
- 新 migration 默认按对现有数据库安全的方式编写，避免在已存在列/表上重复失败
- 如果某条 migration 是近期事故高发点，应同步给 guardrail 增加正向要求或反向拦截

### Cloudflare D1 瞬时故障重试规则

Fabushi 主线 deploy 里的 `wrangler d1 migrations apply` 会直接碰到 Cloudflare 远端 D1 API。像 `Upstream service unavailable [code: 7009]` 这类平台侧瞬时故障，不应被误判成 schema SQL 根因，但也不能用无限重试把真实配置错误掩盖掉。

默认要求：

- 只对已知瞬时平台故障做有限次数重试与退避，不把所有失败都吞掉
- SQL 语法、绑定缺失、数据库 id 错误、权限错误等非瞬时失败，首轮就必须直接失败
- 重试 helper 要作为仓库脚本和 workflow guardrail 一起版本管理，避免后续又漂回裸跑 `wrangler d1 migrations apply`
- 如果有限重试后仍失败，就把事项继续记为发布闭环阻塞，并在 issue / runbook / 下一轮调度里明确标注为“外部平台或迁移门禁仍未恢复”

### GitHub Release 资产规则

Fabushi 当前官网 beta 同步会读取 GitHub Release 资产，但 release 一旦进入 immutable 生命周期，就不能再靠 `gh release upload --clobber` 回写或覆盖资产。

因此涉及 release 后处理时默认遵循：

- 优先在发布时一次性生成需要的资产，而不是依赖 immutable 之后的补写
- 如果 workflow 只是想补官网 beta 状态，而仓库逻辑已经存在 fallback，就把 immutable release 视为已识别外部约束，而不是继续把整条 workflow 打红
- 对这类约束要在 step summary、issue 留言和运行手册里留下明确说明，避免后续重复误判为新的发布根因

### Release 变更检测 checkout 路径长度规则

`Publish CD packages to GitHub Release` 里的 `Resolve completed CD context and mobile changes` 只需要读取 commit 历史来判断 Android / iOS 是否受影响，不需要把整仓长路径素材完整 checkout 到 runner 工作目录。

默认要求：

- 变更检测阶段使用最小化 sparse checkout，只保留 release 元数据或脚本真正需要的少量路径
- 移动端是否变更的判断继续基于 `git diff` / commit object，而不是基于工作目录是否完整落地
- 不要在这个阶段全量 checkout `fabushi/assets/built_in/**`、`fabushi/web/assets/built_in/**` 这类可能包含超长文件名的目录
- 如果只是为了变更检测就触发全量 checkout，导致 `File name too long`，应直接把它视为 workflow 设计缺口，而不是误判成 GitHub 权限、artifact 或 Release API 故障

### Staging E2E 环境契约同步规则

Fabushi 的 staging gate 现在同时跑 `staging_social_privacy` 和 `staging-profile-api` 两条 E2E。只要其中任意测试新增了必填环境变量，workflow 就必须同步更新，而不能让“测试文件已要求、CD workflow 未注入”这种契约漂移直接打断主线发布。

默认要求：

- `fabushi/e2e/tests/**` 中新增或提升为必填的环境变量，要同步更新 `.github/workflows/deploy-production.yml` 里的 `staging-e2e.env`
- 同步更新 `Check staging E2E configuration` 预检步骤，确保缺失变量在跑测试前就被显式指出
- 如果 staging 当前只部署 API worker，而测试临时复用 app-style base URL，那么 workflow 默认值要和当前 staging origin 保持同模，同时保留显式 override 能力
- 这类缺口属于 workflow contract regression，不应误判成 staging 服务本身故障

### 发布闭环观察顺序

每次主线修复合入后，按下列顺序复核：

1. `CI`
2. `CD - Staging API gated production deploy`
3. `Publish CD packages to GitHub Release`
4. GitHub Release 页面与关键资产
5. `TESTFLIGHT_UPLOAD_STATUS.txt` 或等效 TestFlight 证据

若中间任一步失败：

- 先记录首个失败点
- 建立或更新对应 issue
- 修根因
- 重新回到这个顺序继续复核

### 发布覆盖判定与时间规则

对“某个用户反馈是否已经被正式发布覆盖”的判断，不能只看代码是否 merged，还要比较公开发布证据的时间。

默认要求：

- 记录修复 PR 的 `merged_at` 时间
- 记录 latest GitHub Release 的 `published_at` 时间
- 记录 `TESTFLIGHT_UPLOAD_STATUS.txt` 里的上传时间或其他可核对的 TestFlight 证据时间
- 统一使用绝对时间，优先写成 UTC 时间戳，不只写“今天 / 刚刚 / 最新”

只有当公开 release / TestFlight 证据时间晚于相关修复合入时间，才可以把对应 issue 判成“已发布覆盖”。如果公开证据仍早于修复 PR 的合入时间，就必须继续保持为“代码已修、发布覆盖待确认”，不能草率关闭。

### 运行时漂移回判规则

对后端或 Worker 类问题，还要额外防止一种误判：`GitHub Release / TestFlight` 已经晚于修复 merge 时间，不代表生产运行中的 Worker 一定已经切到同一批修复。

出现以下信号时，默认按“运行时漂移或部署覆盖待确认”处理，而不是直接沿用旧 issue 的关闭结论：

- 新 issue 在公开 release 覆盖之后，仍报出与旧问题同一错误签名
- `main` 上关键修复代码仍存在，但真实用户路径继续返回旧错误
- 问题属于 Cloudflare Worker、D1 migration、环境绑定或部署链，而不是纯客户端静态资源

这类情况下默认补做三件事：

1. 重新核对 `main` 上关键修复代码是否仍在
2. 继续回追最近一次主线 `CI -> CD -> GitHub Release` 是否真的覆盖到对应运行时链路
3. 在 issue 中明确标注：当前怀疑点是部署/运行时覆盖，而不是草率宣称代码已回退

## 主控长期状态文件映射

为了让后续自动巡检和人工接手保持同一视角，主控长期状态默认维护以下文件：

- `fabushi-release-gate-status.md`：记录当前 PR、CI/CD、Release、TestFlight 的门禁状态、等待点与最近证据
- `fabushi-upgrade-backlog.md`：记录等待窗口可继续推进的高价值小步升级项、优先级与依赖
- `fabushi-architecture-notes.md`：记录系统性根因、架构判断与长期治理方向
- `fabushi-pr-history.md`：记录已推进 PR 的主题、验证结论与复发预防措施
- `fabushi-controller-state.md`：记录当前活跃工位、等待事项、切回条件与闭环缺口

这些文件可以保存在长期记忆中，但它们对应的规则、命名和用途说明，也应在仓库文档里保持同步，避免 Memory、调度提示词和仓库手册之间出现漂移。

## 主控执行循环

默认循环：

1. 扫描 PR / Issue / 分支 / Actions / Release
2. 把事项分配到对应工位
3. 先处理阻塞主线的确定性问题
4. 等待外部结果时切去其他工位
5. 所有关键事项都在等待时，推进新的小步升级
6. 一旦等待事项有新结果，立即切回
7. 直到所有已发现事项拿到明确结果

## 关闭本轮工作的判定

只有同时满足以下条件，才算当前一轮主控工作可以停止：

- 已发现的 PR、Issue、分支、CI/CD、Release、TestFlight 事项都拿到明确结果
- 没有无人继续跟进的等待项
- 本轮至少完成一项新的迭代升级，并推进到明确结果

## 建议的配套记录

为了让后续自动巡检和人工接手保持同一视角，建议配合维护：

- 当前发布门禁状态
- 活跃 PR 历史与关键修复
- 当前主控状态图
- 可在等待窗口推进的升级 backlog
- 反复出现的系统性根因笔记