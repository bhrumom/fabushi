# Source of Truth

本项目的权威记录位于 `bhrumom/fabushi` 的 `main` 分支 `projects/fabushi-repository-history-slimming/`。跨项目身份以 `projects/PORTFOLIO.json` 和 `projects/PROJECT_ID_POLICY.md` 为准；本项目登记为 `FAB-P0010` / `RHS`。

## Precedence

1. 用户最新明确要求，且已经写入本项目 `source/`。
2. canonical `main` 上的 `projects/PORTFOLIO.json` 与项目记录。
3. 本文件和指定 source 文件。
4. 已接受的 ADR、需求、风险和运行手册。
5. GitHub 的实时 refs、规则、PR、CI 和发布事实。
6. 本地隔离镜像、临时审计输出与对话记忆。

## Conflict resolution

历史重写属于不可逆的高风险操作。若本地镜像与 GitHub 实时 refs 不一致，停止推送并以最新远端 refs 重新生成镜像。若路径保留审计与目标清单不一致，停止重写；不得以对话记忆代替证据。原有 refs 必须先落盘保存，且推送后立即验证并恢复保护规则。

## Evidence rule

本地分析只能证明准备状态，不能证明 GitHub 已完成。完成状态必须由 canonical `main`、远端 head/tag 对照、完整性校验、保护规则恢复记录和对应 CI/审计证据共同证明。
