# 大乘 CLI 小程序市场

## 当前权威架构

任务 `mahayana-marketplace-cloudflare-20260730` 使用“公开 GitHub 源码与共创 + 单一共享 Cloudflare Pages 静态分发 + 本地优先 MCP Apps 运行”的架构。

```text
公开 GitHub 小程序仓库
→ 可信 GitHub Actions 构建 GitHub Release assets
→ 中央发布工作流重新下载、验证并生成全量站点
→ 一个共享 Cloudflare Pages 项目
→ CLI/Host 下载、校验、安装和运行
```

## GitHub 模型

- 默认一个公开仓库对应一个主要小程序。
- 正式版本绑定稳定 repository ID、`owner/name`、精确 commit、tree hash、SPDX license、workflow 和 run ID。
- ChatGPT/Codex 的 GitHub 操作使用官方 GitHub MCP/连接器；禁止为市场自建 GitHub MCP Server。
- 仓库自动化使用 GitHub 原生 Actions、GitHub App、`GITHUB_TOKEN`、OIDC、Releases、rulesets、CODEOWNERS、SBOM 和 artifact attestations。
- Fork PR 使用只读 Token、无 Secret、无生产 OIDC；不得在特权 `pull_request_target` 中执行 Fork 代码。
- PR 合并不等于发布。正式版本必须来自受保护上游 commit、tag/Release 和可信发布工作流。

## 单一 Cloudflare Pages 分发项目

平台只维护一个用于小程序包分发的 Cloudflare Pages 项目。所有项目和历史版本进入同一个完整静态部署快照：

```text
/catalog/v1/index.json
/catalog/v1/revocations.json
/apps/<plugin-id>/index.json
/apps/<plugin-id>/latest.json
/apps/<plugin-id>/releases/<version>/<sha256>/manifest.json
/apps/<plugin-id>/releases/<version>/<sha256>/package.zip
/apps/<plugin-id>/releases/<version>/<sha256>/signature.json
/apps/<plugin-id>/releases/<version>/<sha256>/provenance.json
```

禁止：

- 每个小程序创建独立 Pages 项目；
- 使用 R2 存放安装包或 catalog；
- 覆盖既有版本路径；
- 让市场 API 永久代理全部包正文。

## 不可变发布

- `pluginId + version` 唯一；同版本不同内容发布失败。
- 不可变路径包含 version 和 SHA-256。
- `latest.json` 只是可变指针，不是信任根。
- 旧版本保留以支持可复现安装和回滚。
- 撤销通过签名 catalog/revocation 元数据生效，不通过静默替换旧字节实现。
- Pages 文件大小和文件数量限制在发布前检查；超限必须失败或使用已签名分片，不得自动回退 R2。

## 发布流程

1. 发布者在公开源码仓库创建受保护 tag/Release。
2. 可信 Actions checkout 精确 commit，运行 Tool Contract、MCP Apps、平台兼容、安全与许可证测试。
3. Actions 构建安装包和平台构件，生成 manifest、SHA、SBOM、provenance 与 attestation，上传 GitHub Release assets。
4. 发布请求进入中央分发仓库或可信 reusable workflow。
5. 中央工作流通过 GitHub API 重新下载资产，重新计算 SHA 和大小，验证 plugin ID、version、权限、许可证、来源与不可变性。
6. 审核通过后，中央工作流从全部已批准版本生成完整 catalog 与 Pages 输出目录。
7. 只部署一个共享 Pages 项目。
8. 部署后从公网重新下载新增包和 catalog 复核字节，成功后版本才可安装。

## 市场发现与下载

客户端可以直接读取共享 Pages catalog，也可以通过市场 API 获取签名元数据。最终下载必须指向共享 Pages 的不可变 URL：

```text
https://<shared-pages-domain>/apps/<plugin-id>/releases/<version>/<sha256>/package.zip
```

客户端验证：

1. catalog 与版本元数据签名；
2. HTTPS 域名和不可变路径；
3. SHA-256 与实际大小；
4. plugin ID、version 和平台构件；
5. 权限、CSP、Tool Contract 和 provenance；
6. 撤销、封禁、过期与防回退状态。

## 安装安全

- 下载到随机 staging；
- 限制压缩包和解压后大小；
- 拒绝绝对路径、`..`、符号链接逃逸、设备文件、重复路径和压缩炸弹；
- 校验 `.codex-plugin/plugin.json`、`.mcp.json`、MCP Apps manifest 与签名元数据一致；
- 成功后原子切换，失败清理 staging；
- 权限扩大时重新确认；
- 更新和回滚切换完整 Release，不能混用新旧构件。

## 运行时边界

Cloudflare Pages 仅负责静态分发。小程序可以声明 `local-web`、`desktop-stdio`、`hybrid` 或经批准的远程 MCP Runtime，但运行端点与包分发是不同生命周期。ChatGPT 自动确认可仅支持 desktop native；移动/Web 项目可以使用本地网页或 WASM。

## 完成定义

只有同时满足以下条件才可完成：

- 至少两个独立公开小程序仓库真实发布多个版本；
- 两个项目的包同时存在于同一个 Pages 项目和同一 catalog；
- CLI/Host 可发现、下载、验证、安装、运行、更新和回滚；
- 重复版本不同内容被拒绝，撤销版本不能安装；
- Fork PR 无法读取 Secret、写上游或发布正式构件；
- GitHub 操作使用官方 GitHub MCP/连接器；
- 不存在第二个插件分发 Pages 项目，不使用 R2。
