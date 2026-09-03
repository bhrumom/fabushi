# Original Requirement

User requirement, 2026-08-22:

> 优化cicd，为什么你更新文档也要这么久？，还有合并这些都按照大厂的流程来做

## Diagnosed cause

Current `.github/workflows/ci.yml` sets `FORCE_ALL=true` for every `merge_group` event. As a result, even project-document-only changes that correctly skip product jobs on the PR head are forced through Frontend, Worker, MCP, workflow and Electron checks again after entering the merge queue.

The repository also has production workflows triggered by any successful `CI` workflow on a `main` push; without product-domain impact gating, documentation-only merges can start heavyweight Worker/Fabushi Pay deployment workflows.

## Required outcome

Keep the safety properties of PR review, required checks and merge queue while making validation proportional to risk and changed domains, with explicit fail-safe behavior for unknown code paths.
