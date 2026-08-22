# TFI-GOV-001 — GitHub 项目基线迁移与治理 Skill

- **Task ID**: `TFI-GOV-001`
- **项目**: Fabushi Telegram 全量融合
- **状态**: IN_PROGRESS
- **开始日期**: 2026-08-22
- **来源要求**: 将当前 Telegram 融合项目资料迁入 GitHub；以后以 GitHub 项目文件夹为主；每次任务结束必须更新项目记录；每个新的不同任务必须创建独立项目文件夹；把这些流程写入 Skill。

## 目标

1. 在 `bhrumom/fabushi` 建立 `projects/telegram-fabushi-integration/`。
2. 完整迁移现有项目资料。
3. 将 GitHub `main` 项目目录声明为唯一长期项目基线。
4. 新建 `fabushi-project-governance` Skill，强制开始/结束任务治理流程。
5. 验证项目目录和 Skill 均存在于 GitHub `main`。

## 验收标准

- [ ] `projects/telegram-fabushi-integration/` 完整存在于 GitHub。
- [ ] 原始来源 `source/完整telegram融合进fabushi.txt` 未丢失。
- [ ] `SOURCE_OF_TRUTH.md` 明确 GitHub `main` 为权威基线。
- [ ] `.agent/skills/fabushi-project-governance/SKILL.md` 存在。
- [x] Skill 通过官方 `package_skill.py` validator。
- [ ] 当前任务的状态、WBS、变更日志和 evidence 已回写 GitHub。

## 验证

- Skill validator: **PASS**（2026-08-22）。
- GitHub main folder verification: 待本任务提交后回填。
- GitHub skill verification: 待本任务提交后回填。

## GitHub 证据

- Branch/commit: 待回填。
- PR: 本轮优先以单一原子提交落入 `main`；如分支保护要求 PR，则回填 PR。
- CI: 文档/Skill 迁移不依赖产品构建 CI；仓库写入后验证路径和提交即可。

## 下一步

提交 Telegram 项目资料和治理 Skill；验证 `main` 后将本任务改为 `TESTED/PASSED` 并补齐 commit 证据。
