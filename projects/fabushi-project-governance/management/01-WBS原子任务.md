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

## Status rule

`passed` 只用于 objective acceptance evidence 已存在的原子任务。后续治理改动继续遵守同一规则。
