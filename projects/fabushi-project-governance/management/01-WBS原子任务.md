# WBS 原子任务

| Task ID | Atomic Task | Required | Acceptance Criterion | Verification | Status |
|---|---|---:|---|---|---|
| FPG-001 | 建立仓库级 Project-First Agent 门禁 | yes | 根 AGENTS.md 强制每次任务检查/复用/创建项目目录并在结束前回写记录 | PR #1976 + CI result + main merge | passed |
| FPG-002 | 建立 enterprise project-folder standard 并对齐 Task Orchestration/AGENTS/Skill | yes | FPG-002.1–FPG-002.8 全部通过 | FPG-002 task/evidence | passed |
| FPG-002.1 | 定义 enterprise project folder / stable ID / N/A / no-meta-exemption 标准 | yes | governance standard/reference + ADR-0002 完整 | main file review | passed |
| FPG-002.2 | 更新 root `AGENTS.md` | yes | 包含 enterprise scaffold、meta work 无豁免、completion gate、Task Orchestration alignment | main file review | passed |
| FPG-002.3 | 更新 Fabushi governance Skill/lifecycle | yes | Skill + project-folder standard + task lifecycle 使用同一规则 | main file review | passed |
| FPG-002.4 | 更新并验证 Task Orchestration Skill bundle | yes | quick_validate + package_skill 成功；包含 repository/meta-work project rules | Skill evidence + SHA-256 | passed |
| FPG-002.5 | 治理项目自身迁移为 enterprise standard | yes | mandatory files 全部存在或显式 N/A | main project-folder audit | passed |
| FPG-002.6 | 完成 FPG-002 requirement/acceptance/evidence traceability | yes | source -> requirement -> WBS/task -> evidence 可追踪 | acceptance matrix/evidence index | passed |
| FPG-002.7 | GitHub PR/required CI/protected merge | yes | `CI result` success 且按仓库保护流程合并 | PR #1980 / CI 32556780549 / merge e77e11d4 | passed |
| FPG-002.8 | Canonical `main` verification and closure | yes | main 上关键控制文件和项目目录验证后关闭 FPG-002 | post-merge fetch + closure PR | passed |
| FPG-003 | 评估 CI 项目记录 guardrail | no | 有足够误用证据后决定是否自动化 enforcement | ADR/CI prototype | not-started |
| FPG-004 | 建立跨项目全局不可变 Project ID 体系 | yes | FPG-004.1–FPG-004.7 全部通过 | FPG-004 task/evidence | passed |
| FPG-004.1 | 定义 `FAB-P0001` 单调不复用编号政策与 ADR | yes | policy + ADR-0003 明确 ID/key/legacy alias 生命周期 | main file review | passed |
| FPG-004.2 | 建立 `projects/PORTFOLIO.json` 与项目总览 | yes | 5 个 canonical project 全部登记，next_sequence=6 | main registry + validator | passed |
| FPG-004.3 | 回填全部 canonical `PROJECT.yaml` | yes | 5 个项目均有唯一 `project_id`、`project_key`、slug/path 一致 | main PROJECT.yaml reads + validator | passed |
| FPG-004.4 | 建立自动 Project ID validator | yes | 校验格式、唯一性、连续性、folder parity、base immutability | workflow run 32561929188 | passed |
| FPG-004.5 | 将编号流程写入 AGENTS/governance Skill/lifecycle/standard | yes | 新项目必须先读取 registry 并原子分配 next_sequence | canonical main file review | passed |
| FPG-004.6 | GitHub Actions portfolio governance gate | yes | PR 上 validator workflow success | run 32561929188 | passed |
| FPG-004.7 | Protected merge + canonical main verification | yes | 合并后 registry、5 项目 metadata、控制规则均可从 main 验证 | PR #1996 / merge 87462b14 / main fetch | passed |

## Status rule

`passed` 只用于 objective acceptance evidence 已存在的原子任务。`implemented` 仅表示 branch 上实现已存在但最终 CI/merge/main gate 尚未完成。后续治理改动继续遵守同一规则。