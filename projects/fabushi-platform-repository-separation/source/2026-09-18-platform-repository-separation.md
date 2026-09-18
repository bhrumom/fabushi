# PRS-REQ-000 — 按平台拆分 GitHub 仓库

日期：2026-09-18

## 原始要求

用户要求：把当前仓库拆分，每一个平台一个独立的 GitHub 仓库，不要把所有平台混合在一个
仓库里面；每一个平台创建一个 GitHub 仓库，所有平台分开存放。

## 追加要求

用户明确补充：CLI 也要拆出来，单独一个仓库。

## 已确认基线

- 源仓库：`https://github.com/bhrumom/fabushi`
- canonical `main`（2026-09-18 读取）：`cbe65975f3c4c077fa64af4171ebe3d2900185ad`
- 源仓库当前为 public；新仓库默认保持 public，除非用户另行指定。
- 已存在并继续复用：`bhrumom/fabushi-chatgpt-auto-confirm-userscript`。

## 规范化目标

1. Web、Desktop、Android、iOS、微信小程序、Chrome/Browser、Backend、CLI、Forum、Commerce、
   Marketplace 各自拥有一个独立 GitHub 仓库。
2. 跨平台的 Mahayana/Rust/Telegram/Global Dharma 能力进入独立的共享 Core 仓库；Core
   不是平台产品仓库，但平台只能通过版本化依赖或明确的只读子模块使用它。
3. 原 `fabushi` 在切换完成前保留为迁移源和回滚锚点；最终只保留治理、项目记录、架构
   说明和迁移索引，不再作为多个平台产品的源码仓库。
4. 每个目标仓库都有自己的默认分支、CI、版本/Release、CODEOWNERS、README 和 secrets
   边界。平台代码不得依赖源仓库相对路径。
5. 保留可追溯的历史或记录明确的快照来源；不在本地构建应用，重型导出和验证使用
   GitHub-hosted CI。

## 非目标

- 不删除源仓库或其历史，直到所有目标仓库的迁移/发布/回滚门通过。
- 不在本轮借机重写业务功能、升级依赖或变更账号/组织权限。
- 不把任何 token、cookie、签名材料、`.env` 或测试账户状态复制到目标仓库。

## 2026-09-18 执行读回

- 注册时的历史基线为 `cbe65975f3c4c077fa64af4171ebe3d2900185ad`；本轮正式导出的固定源提交为
  `7851b689d2fe3fc3893cd9f4363899cc4a03e83b`。
- 13 个目标仓库均已完成 GitHub-hosted fresh-mirror 导出并写入各自 `main`；CLI 使用独立的
  `bhrumom/fabushi-cli`，Core 使用 `bhrumom/fabushi-platform-core`。
- 每个目标仓库均保留 `refs/backup/prs-bootstrap-20260918` 回滚引用；正式运行、目标 SHA、路径数量和
  artifact 记录在 `evidence/PRS-005-platform-export-20260918.md`。
- 独立 CI、CODEOWNERS、branch protection、打包/E2E/Release 和生产入口切换仍是后续门；本记录不将
  源码导出误记为产品交付完成。
