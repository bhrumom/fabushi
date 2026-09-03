# Original Requirement

User requirement, 2026-08-22:

> 把这个项目任务流程写入整个fabushi仓库的agent.md文件，要求每次任务都要看项目文件夹，根据文件夹去推进，如果没有项目文件夹就要创建生成项目文件夹和文件

Interpretation persisted for execution:

- The repository root `AGENTS.md` must enforce this workflow for all agent tasks.
- Every task must inspect `projects/` and continue from the matching project record.
- If no project exists for a genuinely different objective/workstream, create a standardized project folder and required files before substantial implementation.
- Task completion must update the project record with status, acceptance, changelog, and evidence.
