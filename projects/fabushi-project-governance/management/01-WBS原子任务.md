# WBS 原子任务

| Task ID | Atomic Task | Required | Acceptance Criterion | Verification | Status |
|---|---|---:|---|---|---|
| FPG-001 | 建立仓库级 Project-First Agent 门禁 | yes | 根 AGENTS.md 强制每次任务检查/复用/创建项目目录并在结束前回写记录 | PR #1976 + CI result success + main merge `eaf273dafc140619b06b46a4d7d234997acde05d` | passed |
| FPG-002 | 根据真实使用校准项目模板 | no | 发现明确缺口时更新标准且保留变更记录 | 后续任务证据 | not-started |
| FPG-003 | 评估 CI 项目记录 guardrail | no | 有足够误用证据后决定是否自动化 enforcement | ADR/CI prototype | not-started |
