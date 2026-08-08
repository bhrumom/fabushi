# 本地生成与双 GitHub 部署模型

## 文档地位

本文件是任务 `mahayana-marketplace-cloudflare-20260730` 关于“用户生成小程序、源码首次保存、上线目标选择、官方托管和用户 GitHub 发布”的最高优先级约束。

若本文件与旧的“生成即上云”“必须先连接 GitHub”“只允许用户自己 GitHub 仓库”或“生成时直接创建远程仓库”设计冲突，以本文件为准。

## 1. 核心原则：生成和上线彻底解耦

用户在法布施 App 的联系人/机器人聊天中与 AI 对话生成小程序时：

```text
AI 生成/修改代码
→ 先写入用户设备的本地小程序工作区
→ 本地校验并可本地运行
→ 用户继续对话迭代
→ 只有用户明确执行“上线/部署/发布”后，才创建或更新远程 GitHub 仓库
```

强制要求：

- 生成代码不依赖 GitHub 登录、GitHub 连接器或网络；
- 首次源码必须先存在本地，远程 GitHub 只是后续发布目标；
- 没有执行上线动作时，不得静默创建 GitHub 仓库或上传源码；
- 上线失败不得破坏本地工作区，本地版本仍可继续运行和编辑；
- 本地工作区保留稳定 `localProjectId`、插件 ID、版本、文件清单和本地 source tree hash；
- Secret、Token、Cookie、私密聊天内容、用户数据、日志和本机缓存不得进入待发布源码快照。

## 2. 上线时只有两个 GitHub 目标

上线入口必须明确展示并记录 `deploymentTarget`：

```text
local-only
official-managed-github
user-github
```

`local-only` 是默认生成状态，不属于线上部署。

### 2.1 官方托管：`official-managed-github`

这是没有 GitHub 账号、没有连接 GitHub，或者希望由法布施托管源码的用户的默认上线路径。

用户条件：

- 只需要登录法布施 App；
- 不要求用户拥有 GitHub 账号；
- 不要求用户安装或授权 GitHub 连接器；
- 用户明确点击或要求“上线”后才执行。

服务端流程：

```text
本地源码快照
→ 法布施登录态鉴权
→ 创建 deployment 记录
→ 使用法布施官方 GitHub App / 组织安装凭证
→ 在 bhrumom 组织创建规范化仓库
→ 写入源码首个 commit
→ 配置仓库模板、Actions、CODEOWNERS、ruleset 和发布边界
→ 回写 repository ID / owner-name / commit / tree hash
→ 运行可信 GitHub Actions
→ 创建正式 Release
→ 注册/更新法布施市场版本
```

组织仓库要求：

- 默认 owner 为 `bhrumom`；
- 一个用户小程序原则上对应一个独立仓库；
- 仓库名不得直接暴露邮箱、手机号、真实姓名等 PII；
- 使用不可猜测的公开项目 ID 或短 ID 处理重名，例如 `miniapp-<slug>-<publicId>`；
- 仓库必须记录稳定 GitHub repository ID，不能只依赖可改名的 owner/name；
- 正式公开市场版本继续满足 SPDX license、source commit、Release Manifest、SBOM、attestation 和签名要求；
- 私人/未公开项目可以先使用私有仓库，但要进入公开市场时必须满足当前公开源码/许可证规则，且必须由用户明确确认公开；
- 官方 GitHub App 的安装 Token 必须短期、最小权限、只在可信后端使用，禁止把组织 PAT 或可写 Token 下发客户端。

### 2.2 用户自己的 GitHub：`user-github`

只有当用户在聊天框的“+”或连接器入口选择/启用了 GitHub 官方连接器，并明确要求部署到自己的 GitHub 时，才走此路径。

流程：

```text
本地源码快照
→ 用户选择 GitHub 连接器
→ 用户明确“部署到我的 GitHub”
→ AI 通过 GitHub 官方 MCP/连接器使用用户授权身份
→ 用户选择或创建目标仓库
→ 写入源码 commit
→ 配置允许范围内的 Actions/模板
→ 返回 repository ID / owner-name / commit / tree hash
→ 法布施只登记来源与发布状态
```

强制边界：

- 用户 GitHub OAuth/MCP 凭证归 GitHub 连接器管理，不得复制给法布施后端；
- 法布施不得拿用户 GitHub Token 代替连接器在后台长期保存；
- 如果 GitHub 连接器未连接、权限不足或用户取消授权，应保留本地代码，并提供切换到“官方托管”的选择；
- 若用户授权的 GitHub 身份可写多个组织，必须让用户明确选择 owner，不得自动猜测；
- 不得因为曾连接过 GitHub 就把后续所有项目静默发布到用户账号；每个新项目首次上线都要显示目标 owner/repository；
- 用户 GitHub 发布成功后，法布施市场仍按稳定 repository ID、精确 commit、tree hash 和许可证校验来源。

## 3. 官方部署 API 合约

至少提供等价于以下能力的受认证 API；具体路由可按现有服务结构实现，但语义不可改变。

### 创建官方托管部署

```http
POST /v2/miniapps/deployments
Authorization: Bearer <fabushi-user-session>
Content-Type: application/json
```

示例请求：

```json
{
  "localProjectId": "local_01H...",
  "target": "official-managed-github",
  "displayName": "我的念佛计数器",
  "visibility": "private",
  "sourceTreeHash": "<local-tree-hash>",
  "sourceArchiveSha256": "<sha256>"
}
```

返回至少包含：

```json
{
  "deploymentId": "dep_01H...",
  "target": "official-managed-github",
  "repository": {
    "provider": "github",
    "owner": "bhrumom",
    "name": "miniapp-nianfo-7f31ab",
    "repositoryId": 123456789,
    "defaultBranch": "main",
    "commit": "<40-char-sha>",
    "treeHash": "<git-tree-hash>",
    "visibility": "private"
  },
  "status": "source-pushed"
}
```

服务端必须对上传快照重新计算文件清单/hash，不得只信任客户端声明的 hash。

### 登记用户 GitHub 部署

通过 GitHub 连接器创建/更新仓库成功后，客户端或受信任 Host 只把非敏感来源元数据登记给法布施：

```http
POST /v2/miniapps/deployments/register-source
```

```json
{
  "localProjectId": "local_01H...",
  "target": "user-github",
  "repositoryId": 987654321,
  "repository": "alice/my-miniapp",
  "defaultBranch": "main",
  "commit": "<40-char-sha>",
  "treeHash": "<git-tree-hash>"
}
```

该接口不得接收 GitHub access token、refresh token 或 connector secret。

## 4. 本地工作区数据模型

每个由聊天生成的小程序至少维护：

```json
{
  "localProjectId": "local_01H...",
  "pluginId": "local.mahayana.01H...",
  "displayName": "我的小程序",
  "workspacePath": "<platform-managed-local-path>",
  "sourceTreeHash": "<hash>",
  "deployment": {
    "target": "local-only",
    "deploymentId": null,
    "repositoryId": null,
    "repository": null,
    "lastPushedCommit": null
  }
}
```

`workspacePath` 只能是平台管理的本地目录/沙箱路径，不得通过市场或公开 API 泄露用户真实磁盘结构。

桌面、iOS、Android 和 Web/PWA 可使用不同底层存储机制，但产品语义必须一致：代码先本地持久化，再选择远程部署。

## 5. 用户体验

聊天生成完成后默认显示：

```text
已保存在本地
[本地运行] [继续修改] [上线]
```

点击“上线”后显示：

```text
上线到哪里？

○ 法布施官方托管（推荐）
  只需当前法布施账号，自动托管到官方 GitHub 组织仓库。

○ 我的 GitHub
  使用已连接的 GitHub 官方连接器发布到我的账户或我有权限的组织。
```

若没有 GitHub 连接器，“我的 GitHub”可显示“连接 GitHub”入口，但不得阻塞“官方托管”。

上线完成必须显示真实目标：

```text
源码仓库：bhrumom/miniapp-nianfo-7f31ab
当前版本：1.0.0
Source commit: abcdef...
部署方式：法布施官方托管
```

或者：

```text
源码仓库：alice/my-miniapp
部署方式：我的 GitHub
GitHub 授权：由 GitHub 连接器管理
```

## 6. 更新与同步

本地代码始终允许继续修改。

已上线项目再次修改时：

- 默认目标仍是该项目最近一次明确选择的仓库；
- 推送前显示将要更新的 repository 和 branch；
- 如果远程已经出现用户未同步的提交，必须先 fetch/compare，再由 AI 辅助 merge/rebase；
- 不允许强推覆盖远程未知提交；
- 用户可执行“另存为新部署”，切换为官方托管或另一个 GitHub 仓库，但必须生成新的 deployment 记录；
- 切换目标不得删除原远程仓库，也不得删除本地项目。

## 7. 发布与运行保持现有多构件模型

仓库建立后，继续使用现有 GitHub-native MCP App 供应链：

```text
source repository
→ trusted main CI
→ protected tag/release
→ common + native-* + web-wasm
→ SBOM + artifact attestations + provenance
→ 市场登记
→ 客户端按平台下载最小构件
→ 本地运行
```

“托管源码到 GitHub”与“创建正式市场 Release”是两个阶段。源码首次推送成功不等于已经公开发布，也不等于立即进入市场。

## 8. 安全与隐私

必须实现：

- 发布前 Secret 扫描和敏感文件 denylist；
- `.env`、凭证文件、本地数据库、聊天记录、缓存、构建产物默认不上传；
- 官方组织仓库创建 API 只接受登录用户自己的 `localProjectId`；
- 服务端校验部署记录与用户所有权，防止 IDOR；
- 仓库创建和首次 push 操作必须具备幂等键，避免重试生成多个仓库；
- 所有仓库写操作记录审计事件；
- 删除法布施账号不得静默删除用户 GitHub 仓库；官方托管仓库删除/转移必须是独立、明确、可审计操作；
- 用户自己的 GitHub 仓库由用户 GitHub 权限和 GitHub 连接器控制，法布施不得绕过。

## 9. 强制真实验收

该能力至少需要以下真实证据：

1. 完全不连接 GitHub 的新用户，在法布施登录后与 AI 对话生成一个真实 MCP App；
2. 代码先真实写入本地工作区，断网后仍可打开、继续修改并本地运行；
3. 用户点击“官方托管上线”，无需 GitHub 账号即可在 `bhrumom` 下创建真实独立仓库；
4. 组织仓库首个 commit 的源文件与本地发布快照一致，hash 可复核，且无 Secret/缓存/聊天内容；
5. 组织仓库配置真实 Actions、CODEOWNERS/ruleset，并能继续走可信 Release；
6. 同一个本地项目另做一条测试：连接 GitHub 官方连接器后，明确部署到测试用户自己的 GitHub 仓库；
7. 用户 GitHub Token/connector secret 不出现在法布施 API、日志、数据库或仓库；
8. GitHub 连接器断开后，本地项目和官方托管部署仍可正常使用；
9. 已部署项目再次由 AI 修改时能安全 push 新 commit，遇到远程分叉不会强推覆盖；
10. 用户明确公开后，Release、市场来源、repository ID、source commit、tree hash、SBOM、attestation 与安装包全部一致；
11. iOS、Android、macOS、Windows、Linux、Web/PWA 至少按现有平台验收矩阵证明“远程分发、本地运行”。

只有这两条发布路径都取得真实端到端证据，才可报告本任务的“用户生成小程序上线”能力完成。
