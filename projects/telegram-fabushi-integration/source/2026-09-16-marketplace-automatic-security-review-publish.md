# 2026-09-16 Marketplace 自动安全审核与自动上架

## 用户目标

将 Fabushi 现有 Mini App / 插件 Marketplace 升级为自动审核、自动上架体系：所有纳入 `.agents/plugins/marketplace.json` 的官方小程序/插件必须经过统一安全审核；审核通过后无需人工逐项改公开目录即可进入公开 Marketplace；审核失败必须 fail closed，不能被搜索、安装或发布。

2026-09-16 继续要求：把剩余控制面阻塞全部闭环，直到真实插件变更自动完成 write-back → final-head CI → protected automerge → merge-group → canonical `main` 上架，不接受“主体完成、最后一步人工操作”作为完成。

## 约束

- 继续复用 `FAB-P0001 / TFI`、`M8 Mini Apps` 与 `M8-MARKET-003` 的 GitHub immutable install/update contract，不创建第二套 Marketplace/安装协议。
- 以 GitHub Actions 作为免费 CI/orchestration；真正的审核由确定性 Fabushi policy、CodeQL、Semgrep CE、Trivy、OSV/SBOM/漏洞扫描等组成。
- PR / merge-group 的不可信源码审核必须 read-only，不允许插件代码取得发布凭据。
- privileged auto-publish 只能由 canonical default-branch workflow 在 exact-head `CI` 成功后执行；fork PR 禁止 write-back。
- auto-publish 不开启仓库级 “Actions 可创建/批准 PR” 权限，也不引入 PAT。公开 catalog + approval ledger 必须作为生成文件写回同一个插件源码 PR，再确保 **最终当前 PR head** 已通过 `CI result` 并交给现有 protected merge controller / merge queue。
- 自动 write-back 不接受同时修改 `scripts/`、`.github/`、`.semgrep/` 等安全/发布工具的 PR；基础设施变更必须先独立 protected merge，后续插件 PR 才能复用新的 canonical policy。
- trusted publisher 可在 workflow job 范围取得完成既有职责所需的最小 `pull-requests: write`，仅用于 same-repo、已通过审计的 PR 标签授权；不得因此给 fork PR 或不可信 PR 代码 write token。
- final-head CI 必须幂等：如果 generated/current head 已有 exact-SHA successful `CI` 则复用；否则用 `workflow_dispatch` 明确运行并等待成功。不得以 `generator changed=false` 作为跳过最终 head 验证的理由。
- 发布/安装身份必须绑定 `plugin id + version + deterministic plugin digest`；同一已批准版本源码变化后旧审核证明立即失效，必须升版本重新审核。
- Secret、credential、private key、危险下载执行链、未声明/不安全 runtime descriptor、依赖高危漏洞等必须 fail closed。
- 审核证据必须作为 GitHub Actions artifact 保留，并提供 machine-readable JSON。
- 外部 scanners 不得成为唯一信任根；即使第三方 scanner 不可用，Fabushi deterministic policy 仍需 fail closed 或明确阻塞发布。

## 自动审核与上架目标流水线

1. 插件源码 + `.agents/plugins/marketplace.json` 进入 same-repository PR；开发者不手改 public catalog / approval ledger。
2. required `CI result` 调用完整 `Marketplace Security Review`。
3. Fabushi deterministic marketplace/policy audit。
4. Semgrep CE + Fabushi custom rules。
5. Trivy filesystem vulnerability/secret/misconfiguration scan。
6. OSV dependency scan。
7. Syft SBOM + Grype vulnerability scan。
8. CodeQL `security-extended`（JavaScript/TypeScript、Python、Rust）。
9. 生成 `fabushi.marketplace.audit.v1` report，包含每个插件 immutable digest、版本、source SHA、decision/findings；任一 required audit 失败则禁止继续。
10. exact PR head 的 `CI` 成功后，trusted default-branch `Marketplace Auto Publish` 解析该 PR；仅 same-repo、仅插件/内部 registry 变更才可进入 privileged staging。
11. workflow 再次运行 deterministic audit + generator，确定性生成 public catalog + `fabushi.marketplace.approvals.v1` ledger；若有变化，只允许这两个 generated path 发生 diff。
12. generated files 自动 commit/push 回同一个 source PR。
13. workflow 重新读取 PR 的最终当前 head；若该 exact SHA 尚无 successful `CI`，显式 `workflow_dispatch` `ci.yml` 并等待该 exact SHA 成功；若已经成功则幂等复用。
14. 只有 final-head CI 成功后，trusted publisher 才添加现有 `automerge` 授权标签并显式 dispatch 仓库现有 `automerge.yml`；该控制器继续执行敏感路径检查、required product gates，并把 PR 放入 protected merge queue。
15. merge-group 对最终组合候选再次执行 required `CI result`；只有 merge queue 合并后的 canonical `main` 才成为公开上架事实。
16. public catalog 只包含具有当前 `approved` ledger + matching digest 证明的插件版本。

## Open-source-first 调研

- GitHub CodeQL / `github/codeql-action@v4`: GitHub 官方 SAST，公开仓库可用于 Code Scanning；采用 `security-extended`。
- Semgrep CE (`semgrep/semgrep`, LGPL-2.1): 多语言 pattern SAST；用于 Fabushi 自定义危险行为规则。
- Trivy (`aquasecurity/trivy`, Apache-2.0): filesystem vulnerability/secret/misconfiguration 扫描。
- OSV-Scanner (`google/osv-scanner`, Apache-2.0): 依赖漏洞数据库与 GitHub reusable workflow / CLI；采用 v2 系列。
- Syft/Grype (`anchore/syft`, `anchore/grype`, Apache-2.0): SBOM + vulnerability scan，作为供应链二次交叉验证。
- Sigstore/cosign (`sigstore/cosign`, Apache-2.0): 后续可用于 Release/attestation signing；本任务先固化 digest + GitHub source SHA + Actions artifact evidence，不要求新增长期私钥。
- gVisor (`google/gvisor`, Apache-2.0): 成熟不可信 workload sandbox 参考；GitHub-hosted runner 上的通用第三方 MiniApp runtime 动态执行需要独立 runner/sandbox contract 后再启用，不能用普通 Docker 冒充完整 sandbox。
- GitHub 官方 `GITHUB_TOKEN` / workflow syntax 文档：workflow 可按 job/workflow 声明最小权限；`pull-requests: write` 是修改 PR（含标签）的权限；由 `GITHUB_TOKEN` 发出的普通事件默认不递归触发 workflow，但 `workflow_dispatch` / `repository_dispatch` 是明确例外，可用于安全、显式的下一阶段 CI orchestration。

## 本轮实现边界

本轮关闭“仓库内所有官方 Mini App / 插件自动安全审核 + 同一源码 PR 自动生成上架数据 + final-head CI + protected merge queue 发布”的闭环。任意第三方 fork / 外部仓库的服务端动态 submission 仍需要后续把同一 audit protocol 接到 Marketplace ingestion worker + 真正 hostile-code sandbox；在该接入完成前保持 `pending_review`，不降低现有安全门禁。
