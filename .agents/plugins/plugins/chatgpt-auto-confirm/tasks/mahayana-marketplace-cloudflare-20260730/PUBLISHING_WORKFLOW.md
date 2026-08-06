# 发布流程：GitHub Release 到单一共享 Cloudflare Pages

## 1. 默认发布模型

```text
公开小程序源码仓库
→ 可信 GitHub Actions
→ GitHub Release assets
→ 中央分发仓库验证与组装
→ 单一共享 Cloudflare Pages 项目
→ 客户端 catalog/download/install
```

普通发布者不需要 Cloudflare Token，不创建 Pages 项目。GitHub 仓库操作使用官方 GitHub MCP/连接器；仓库自动化使用 GitHub 原生 Actions、GitHub App、`GITHUB_TOKEN`、OIDC 和 Releases。

## 2. 小程序源码仓库

默认一个仓库对应一个主要小程序，至少包含：

```text
.github/workflows/pr-untrusted.yml
.github/workflows/release-trusted.yml
.github/CODEOWNERS
.codex-plugin/plugin.json
.mcp.json
mcp-app.yaml
permissions.json
tools.json
ui/
runtime/
tests/
LICENSE
CONTRIBUTING.md
SECURITY.md
```

正式版本绑定 repository ID、精确 commit、tree hash、SPDX license、workflow 和 run ID。

## 3. PR 流程

Fork PR 只能运行：

```yaml
permissions:
  contents: read
```

允许构建、单元测试、Tool Contract、MCP Apps conformance、静态扫描和权限差异检查。不得提供 Secret、写权限、生产 OIDC 或正式签名；不得使用特权 `pull_request_target` 执行 Fork 代码。

## 4. 可信 Release 构建

受保护 tag/Release 触发可信工作流：

1. checkout 精确 commit；
2. 安装锁定依赖；
3. 运行 Tool Contract、MCP Apps、平台兼容与安全测试；
4. 构建 common、native、web-wasm 或项目声明的最小构件；
5. 生成安装包、manifest、permissions、SBOM、SHA-256、provenance 和 artifact attestation；
6. 验证 plugin ID、version 与 tag；
7. 上传不可变 GitHub Release assets；
8. 生成发布请求，指向 repository ID、commit、workflow/run、Release ID 和 asset IDs。

PR 合并本身不发布正式版本。

## 5. 中央发布请求

发布请求可以通过中央仓库 PR、受控 repository dispatch 或可信 reusable workflow 提交，但只能传递身份和元数据，不得把调用方给出的哈希直接当作可信结果。

中央工作流必须：

1. 使用 GitHub API 从 Release 重新下载资产；
2. 重新计算 SHA-256、大小和文件清单；
3. 验证 plugin ID、version、权限、许可证、commit、workflow、attestation 和 provenance；
4. 检查同一 `pluginId + version` 是否已存在；已有不同内容则失败；
5. 执行包安全、MCP Apps 和平台构件验证；
6. 进入审核或自动政策判定；
7. 仅把批准版本加入共享分发树。

## 6. 共享 Pages 输出

```text
site/
├── catalog/v1/index.json
├── catalog/v1/revocations.json
└── apps/
    └── <plugin-id>/
        ├── index.json
        ├── latest.json
        └── releases/<version>/<sha256>/
            ├── manifest.json
            ├── package.zip
            ├── package.sha256
            ├── signature.json
            ├── provenance.json
            └── sbom.json
```

中央工作流每次从已批准版本账本重新构建完整静态快照。版本目录不可覆盖；`latest.json` 和 catalog 可以变化。旧版本保留，撤销通过签名撤销元数据生效。

## 7. Cloudflare Pages 部署

- 只使用一个小程序包分发 Pages 项目。
- 所有项目、版本和 catalog 一次性作为完整站点部署。
- 不为插件创建独立 Pages 项目。
- 不使用 R2。
- 部署前验证 Pages 单文件和文件数量限制；超限则失败或使用已签名分片包。
- 部署完成后，从最终公开 Pages URL 重新下载每个新增包和 catalog，复核 SHA、大小、缓存头和可访问性。

## 8. 最终 URL

```text
https://<shared-pages-domain>/apps/<plugin-id>/releases/<version>/<sha256>/package.zip
```

同一 Pages 域名服务全部项目。市场 API 可以返回或重定向到该不可变 URL，但不得永久代理包正文。

## 9. 安装流程

1. 读取并验证共享 catalog；
2. 选择匹配平台的最小构件；
3. 下载不可变包；
4. 校验签名、SHA、大小、plugin ID、version、权限、provenance 和撤销状态；
5. 在随机 staging 中安全解包；
6. 原子切换 current；
7. 记录安装收据和最高安全版本。

## 10. 更新、回滚和撤销

- 更新生成新版本目录，不覆盖旧版本。
- 回滚指向已批准且未撤销的历史 Release。
- 撤销不删除字节，但 catalog 和客户端必须阻止新安装、升级和启动策略要求的版本。
- 权限扩大必须重新确认。

## 11. 发布证据

每次中央发布必须产出：

```text
release-request.json
source-verification.json
asset-inventory.json
package-validation.json
catalog-diff.json
pages-deployment.json
public-redownload-verification.json
release-receipt.json
```

收据记录 repository/commit/workflow/run、Release/asset IDs、plugin/version、Pages project/deployment、最终 URL、SHA、大小、签名、provenance、审核和撤销状态。

## 12. 禁止做法

- 自建 GitHub MCP Server；
- 每插件一个 Pages 项目；
- R2 分发；
- 信任发布者提交的哈希而不重新下载计算；
- 同版本覆盖；
- Fork PR 获得 Secret、写权限或生产 OIDC；
- PR 合并即发布；
- 市场永久代理全部下载字节；
- 只发布一个硬编码示例插件。
