# 2026-09-05 — M6 MAINSAFE VERSION exact-head 执行验证与代码审查交接

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Product PR: `#2345`
- Branch: `fix/tfi-m6-mainsafe-001-version-exact-head-checkout-001`
- Canonical base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture source: `#2340@9da26347e6de37a6576198b0f09d36928cbb1b0a`, handoff comment `5548081273`
- Pre-record implementation head: `76174474fec9b3681fea7e1960f0fc468093d94c`
- Record state: `SELF-BINDING-FINAL-HEAD-VALIDATION-PENDING`

## 执行范围

本续作只在既有 #2345 上补齐 TFI records，不重新实现、不创建第二个产品 PR。产品实现保持：

- `.github/workflows/ci.yml`：PR checkout 明确绑定 `github.event.pull_request.head.sha`；merge_group 绑定 `github.event.merge_group.head_sha`；canonical script 前用 `git rev-parse HEAD` fail-closed 比对事件期望 SHA；`CI result` 仍只接受 canonical child exact `success`。
- `mobile/ios/project.yml`：仅 `CURRENT_PROJECT_VERSION 28 -> 29`。
- canonical script、`app-version.json`、Android/Electron/Cargo/dependencies、其它 workflow、ruleset/branch protection、应用/测试源码、release 配置均不因本 records 写回而修改。

除上述两个实现/config 文件外，本 records commit 只能修改 `projects/telegram-fabushi-integration/**`。

## 最终 head 自绑定规则

包含本文件与 `VERSION-EXACT-HEAD-CHECKOUT-EXECUTION-2026-09-05.md` 的提交，正常 fast-forward 推送后即成为待验证的最终 records-bearing product head。其 exact SHA、自动 PR Actions run/job IDs、URLs 与 raw-log expected/actual HEAD 事实必须在推送后从 GitHub 读回，并在 **不产生新 Git commit** 的 #2345 不可变执行交接评论中封存。

任何后续 Git commit 都会改变 final head，并使此前 exact-head Actions 证据自动失效。

## 代码审查放行条件

只有当同一最终 head 同时满足：最终 allowlist 无越界；自动 `pull_request` canonical job raw log 证明实际 HEAD 严格等于最终 product head；canonical script 在该断言后执行成功；same-run `CI result` SUCCESS；portfolio governance 与其它适用自动 checks 全部真实通过，执行方才可在 #2345 留下 `EXECUTION-VERSION-EXACT-HEAD-CHECKOUT-001-PASS-CANDIDATE` 评论。

该评论是唯一执行→代码审查放行信号。代码审查项目组必须在其现有唯一标签页中**新开一个聊天**，独立审查评论中冻结的 #2345 exact final product head。不得审查旧 head、#2343 synthetic merge 或任何 sibling green 作为替代。

若 final-head raw evidence 未完成/失败、changed-files 越界或任何适用 check 不绿，则状态必须保持 `EXECUTION-BLOCKED`，不得交给代码审查。

## 未授权下游动作

本执行任务不加入 merge queue、不合并、不进行测试发布、不进行正式发布。即使执行形成 PASS-CANDIDATE，唯一下一动作仍是独立代码审查；protected merge_group、merge、canonical-main readback、packaged test release 与 stable release 均由后续独立门禁负责。
