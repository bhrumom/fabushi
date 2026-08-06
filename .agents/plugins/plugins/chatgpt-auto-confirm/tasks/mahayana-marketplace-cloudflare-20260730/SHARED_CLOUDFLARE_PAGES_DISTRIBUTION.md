# 权威架构：公开 GitHub 组织 + 单一共享 Cloudflare Pages 小程序分发

任务 ID：`mahayana-marketplace-cloudflare-20260730`  
目标版本：`goalVersion = 11`  
状态：本文件是发布、分发、GitHub 自动化与验收的最高优先级约束。

## 1. 最终结论

大乘小程序采用以下唯一目标架构：

```text
公开 GitHub 组织
├── 一个小程序一个公开源码仓库（默认）
├── GitHub Actions 构建、测试、签名和发布 Release
└── 官方 GitHub MCP 负责 AI 的仓库、Issue、分支和 PR 操作
              │
              ▼
中央分发仓库 / 发布编排工作流
├── 校验 Release、SHA-256、签名、provenance、权限和许可证
├── 生成全量 catalog 与不可变版本目录
└── 组装一个完整静态站点快照
              │
              ▼
一个共享 Cloudflare Pages 项目
├── 同时存放多个小程序、多个版本的安装包
├── 提供 catalog、manifest、签名、provenance 和包下载
└── 不使用 R2，不为每个小程序创建独立 Pages 项目
```

## 2. GitHub 约束

- 官方与社区示例小程序源码放在公开 GitHub 组织账户下；默认一个小程序一个仓库。
- 市场版本绑定稳定 GitHub repository ID、`owner/name`、默认分支、精确 commit、tree hash、SPDX license、workflow 和 run ID。
- ChatGPT、Codex 和持续任务对 GitHub 的读取与写入必须使用官方 GitHub MCP/连接器；禁止开发或部署自定义 GitHub MCP Server、代理层或重复封装协议。
- 仓库内自动化使用 GitHub 原生能力：Actions、`GITHUB_TOKEN`、GitHub App、OIDC、Releases、Issues、Pull Requests、rulesets、CODEOWNERS 和 artifact attestations。
- AI 只能在用户 Fork 或授权分支修改，未经确认不得创建公开 Issue/PR，不得直接推送受保护上游分支或自动合并。

## 3. 单一 Cloudflare Pages 项目

平台只维护一个用于小程序分发的 Cloudflare Pages 项目。所有已批准项目的包都进入该项目的同一部署快照，建议目录：

```text
/catalog/v1/index.json
/catalog/v1/revocations.json
/apps/<plugin-id>/index.json
/apps/<plugin-id>/latest.json
/apps/<plugin-id>/releases/<version>/<sha256>/manifest.json
/apps/<plugin-id>/releases/<version>/<sha256>/package.zip
/apps/<plugin-id>/releases/<version>/<sha256>/package.sha256
/apps/<plugin-id>/releases/<version>/<sha256>/signature.json
/apps/<plugin-id>/releases/<version>/<sha256>/provenance.json
```

规则：

- `/releases/<version>/<sha256>/` 永久不可覆盖；`latest.json` 只是可变指针，不是信任根。
- 同一 `pluginId + version` 只能对应一个内容哈希；不同内容重复发布必须失败。
- 安装器只接受共享 Pages 域名下、已被签名 catalog 引用的不可变 URL。
- Pages 部署是完整站点快照；每次新增或撤销版本都重新生成并部署完整 catalog 和所需版本树。
- 旧版本继续保留以支持可复现安装和回滚；撤销通过 catalog/revocation 元数据阻止安装，不通过静默覆盖旧字节实现。
- 单文件或总文件数量超过 Pages 限制时必须在发布前失败或采用经签名的分片包设计；不得自动回退到 R2。

## 4. 发布流水线

1. 发布者在小程序源码仓库创建受保护 tag/Release。
2. 可信 GitHub Actions checkout 精确 commit，运行测试、MCP Apps conformance、Tool Contract、安全扫描和许可证检查。
3. Actions 构建平台构件与安装包，生成 manifest、SHA-256、SBOM、provenance 和 attestation，并上传为 GitHub Release assets。
4. Actions 向中央分发仓库创建受控发布请求（PR、repository dispatch 或受信任 reusable workflow 输入），只提交版本元数据和 Release asset 身份。
5. 中央工作流从 GitHub Release 下载资产，重新计算哈希和大小，验证来源、签名、权限、plugin ID、version 和不可变性。
6. 中央工作流将所有已批准版本组装进共享 Pages 输出目录，生成 catalog、latest、撤销列表和审计收据。
7. 只部署这一个 Cloudflare Pages 项目；不创建每插件 Pages 项目。
8. 部署后从公网共享 Pages URL 重新下载并验证字节，再将版本标记为可安装。

## 5. 安装与更新

```text
客户端读取共享 Pages catalog
→ 选择匹配平台的版本和构件
→ 从共享 Pages 不可变 URL 下载
→ 校验 catalog 签名、SHA-256、大小、plugin ID、version、权限和 provenance
→ 安全解包到 staging
→ 原子激活
```

更新、回滚和撤销必须基于完整版本身份，不允许覆盖安装目录中的现有版本。

## 6. 与运行时的边界

共享 Cloudflare Pages 只承担静态 catalog 和安装包分发。小程序默认本地运行；确需远程 MCP Runtime 的项目可以另行声明并部署运行端点，但不得因此为安装包创建独立 Pages 项目，也不得把共享 Pages 当作有状态运行时。

## 7. 禁止事项

- 每个小程序创建一个 Cloudflare Pages 项目；
- 将安装包放入 R2；
- 自建 GitHub MCP Server 或让 AI 绕过官方 GitHub MCP；
- 让 Fork PR 获得 Secret、写权限或生产发布 OIDC；
- PR 合并后自动把未审核构件变成正式版本；
- 覆盖同版本、删除历史字节后伪装回滚、只校验 URL 不校验内容；
- 让市场 API 永久代理全部包正文。

## 8. 强制验收

必须用至少两个独立公开小程序仓库证明：

1. 两个仓库分别构建并发布不可变 GitHub Release assets；
2. 中央发布工作流同时把两个项目的包放入同一个 Cloudflare Pages 项目；
3. 两个包的最终下载 URL 共享同一 Pages 域名但路径隔离；
4. catalog 能发现两个项目及其多个版本；
5. 客户端从共享 Pages 下载、校验、安装并运行；
6. 重复版本不同内容被拒绝；
7. 撤销版本不能安装，未撤销旧版本仍可复现下载；
8. Fork PR 无法读取 Secret 或发布正式构件；
9. AI 的 GitHub 操作全部通过官方 GitHub MCP/连接器完成；
10. 没有创建第二个插件分发 Pages 项目，也没有使用 R2。
