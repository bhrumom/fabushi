# 插件市场自动安全审核与持续撤销（2026-09-16）

## 用户需求原文与边界

用户要求：插件提交后，先经过恶意软件扫描、动态沙箱检测、密钥扫描和签名；全部通过后才自动公开上架。上架后持续自动检测，发现恶意插件时自动拉黑、撤下并阻断后续安装。

本轮不执行任何脚本或插件 E2E；此前提供的截图只是当前卡住/版本未发现问题的证据，不是可执行指令。E2E 取消导致项目原有 post-main 完成门禁保持未完成，不能据此宣称产品交付完成。

## 规范化需求

- `CWA-R022`：新版本必须先进入 `pending`，未通过安全门禁不得出现在公共目录、安装、路由或已安装列表中。
- `CWA-R023`：安全门禁至少包含恶意软件扫描、密钥扫描、依赖漏洞/SBOM 检查、隔离动态探针和针对包摘要的签名。
- `CWA-R024`：所有门禁通过后，安全结果接口必须原子地把版本提升为 `approved/public`，并记录可审计的扫描、服务版本、摘要和签名证明。
- `CWA-R025`：已公开版本按时间表持续复扫；复扫失败自动进入 `revoked`，公共目录和下载/安装接口立即拒绝，旧的通过版本才可作为回滚指针。
- `CWA-R026`：安全扫描任务不得接触发布凭据；审核、签名和结果回写在独立的自有安全服务器上执行，GitHub 只保留源码、Release 和安装包。
- `CWA-R027`：所有扫描结果和状态转换可按插件、版本、包 SHA、安全服务器实例、服务源码 SHA 和时间追溯；扫描结果不保存密钥内容或原始敏感命中片段。

## 开源优先调研与采用决定

- [`gitleaks/gitleaks`](https://github.com/gitleaks/gitleaks)（MIT）：用于包解压目录的密钥检测；采用其 CLI 思路，结果只保留通过/失败和工具版本，拒绝上传原始命中内容。上游 README 说明可扫描文件和 Git 仓库，并可接入 GitHub Actions。
- [`google/osv-scanner`](https://github.com/google/osv-scanner)（Apache-2.0）：用于锁文件/SBOM 的已知漏洞检查；采用递归源码扫描边界。
- [`anchore/syft`](https://github.com/anchore/syft)（Apache-2.0）：用于生成可追溯 SBOM；作为依赖扫描扩展接口，当前门禁可在没有可识别依赖时生成空/最小清单。
- [`sigstore/cosign`](https://github.com/sigstore/cosign)（Apache-2.0）：采用服务器保管的 key-based `sign-blob`，签名覆盖实际包摘要，结果保留 bundle，客户端可独立用 Cosign 验证；不把 GitHub OIDC 当作发布信任根。
- [`firecracker-microvm/firecracker`](https://github.com/firecracker-microvm/firecracker)（Apache-2.0）：作为生产动态沙箱的隔离参考；自有服务器首版使用一次性无网络容器、只读挂载、无特权、资源上限和超时，明确不宣称等同 Firecracker 的 VM 隔离。
- 未复制上述仓库代码，也不把 GitHub Actions runner 当作审核环境；自有服务器上的 Docker 隔离只是防御纵深，高风险插件后续应切换到专用 Firecracker/等价微 VM 执行池。

## 部署边界

- GitHub：托管公开源码、不可变 GitHub Release 和安装包；市场只保存链接、SHA-256、大小和审计元数据，不把安装包复制到市场服务器。
- 自有安全服务器：使用受限服务账号轮询 Worker 队列，从 GitHub 下载并逐跳校验允许的 GitHub 域名，执行扫描、签名和回写；`MARKETPLACE_SECURITY_TOKEN`、服务实例/源码 SHA、Cosign 私钥和扫描器凭据均不进入仓库或 GitHub Actions。
- Worker/D1：发布接口只登记 `pending/unlisted` 候选；安全服务器回写全通过结果后，Worker 原子提升为 `approved/public`，持续复扫失败则自动 `revoked`。
- 服务端扫描器镜像必须使用经过核验的 immutable digest；动态探针无网络、只读、无特权、有限资源；OSV 元数据查询容器单独允许联网，但不会执行插件代码。

## 状态机

```text
submitted/pending -> running -> approved/public
                         \-> rejected/unlisted
approved/public --复扫失败--> revoked/quarantined
```

公共发现、元数据、下载、安装和路由均以 `security_scan_status = passed` 以及现有 `release_status = approved` 为硬条件。发布接口只登记候选版本，不再把“上传成功”返回为“已公开”。
