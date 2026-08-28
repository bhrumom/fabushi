# MDA-301 Isolated skill staging

Status: in-progress

Objective: copy Skill resources into a managed project-private path without mutating source bundles.

Implementation: trusted Host `stageBundle`/`stageDesignSkill`; destination is under app-managed `workspaces/<workspaceId>/.mahayana/staged-skills/`.

Security: absolute/traversal paths and symbolic links are rejected; source bundle is copied rather than linked.

Verification: Node filesystem/security tests including source-mutation isolation and symlink rejection. PR/CI evidence pending.
