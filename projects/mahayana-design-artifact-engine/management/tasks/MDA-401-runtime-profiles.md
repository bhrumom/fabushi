# MDA-401 Declarative runtime profiles

Status: in-progress

Objective: absorb OpenDesign's useful data-driven adapter idea without creating a second agent loop.

Implementation: Host exposes declarative profiles for Codex, Grok Build, Claude Code, DeepSeek Harness and Cursor Agent. Profiles contain executable names, stream format and capabilities only.

Boundary: Mahayana remains lifecycle/session/tool/policy owner. Profiles have no `run()` or `cancel()` behavior.

Verification: contract test asserts declarations contain no loop methods; existing runtime-convergence guard remains required. PR/CI evidence pending.
