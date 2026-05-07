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
- 在 PR 真正 `merged` 之前，不关闭对应修复 issue，也不宣称问题已经进入主线
- 等待 queue 外部结果期间，立即切去其他工位推进事项或新的小步升级；一旦 queue 出现 merge / fail 新信号，再立刻切回
- PR 真正 merged 后，继续按 `main -> CI -> CD -> GitHub Release -> TestFlight` 顺序复核，而不是把 queue 放行为最终终点

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

### GitHub Release 资产规则

Fabushi 当前官网 beta 同步会读取 GitHub Release 资产，但 release 一旦进入 immutable 生命周期，就不能再靠 `gh release upload --clobber` 回写或覆盖资产。

因此涉及 release 后处理时默认遵循：

- 优先在发布时一次性生成需要的资产，而不是依赖 immutable 之后的补写
- 如果 workflow 只是想补官网 beta 状态，而仓库逻辑已经存在 fallback，就把 immutable release 视为已识别外部约束，而不是继续把整条 workflow 打红
- 对这类约束要在 step summary、issue 留言和运行手册里留下明确说明，避免后续重复误判为新的发布根因

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
