# PRS-006 — iOS Actions secret migration

- Project ID: FAB-P0013
- Project Key: PRS
- Task ID: PRS-006
- Source requirements: PRS-REQ-004, PRS-REQ-009, PRS-REQ-011
- Status: in-progress
- Started: 2026-10-03
- Updated: 2026-10-03
- Source: bhrumom/fabushi canonical main
- Target: fabushi-ios/fabushi-ios

## Objective

迁移当前 canonical iOS GitHub Actions 实际引用的组织级 secrets 到独立 iOS 仓库 Actions secrets，保留原值；以一次性最小权限 relay 传送，不让配置值出现在代码、页面文本、聊天或 Actions 日志。

## Scope

- Include only the six secrets referenced by the active iOS lanes in .github/workflows/release-ios.yml and the iOS job of .github/workflows/apple-store-delivery.yml:
  - APP_STORE_CONNECT_API_KEY_ID
  - APP_STORE_CONNECT_API_ISSUER_ID
  - APP_STORE_CONNECT_API_KEY_BASE64
  - IOS_CERTIFICATE_P12_BASE64
  - IOS_CERTIFICATE_PASSWORD
  - IOS_PROVISIONING_PROFILE_BASE64
- Exclude macOS signing secrets/variables, unrelated organization secrets, and disabled or non-iOS workflows.
- Do not copy or log secret values.

## Dependencies

- Source repository Actions must receive the existing organization secrets.
- Target repository must accept Actions secrets using a fine-grained token limited to that repository's Secrets write permission.

## Acceptance criteria

1. The six names are validated against active iOS workflow references on canonical source main.
2. All six target repository Actions secret names are present after the relay; values are never read back.
3. A single GitHub Actions relay run succeeds and reports only secret names/status.
4. The temporary target token, source repository token secret, relay workflow, PR branch, and transient files are removed after readback.
5. The task record records PR, Actions run, verification, cleanup, and blockers without any secret value.
6. No local project build or test is run; post-main product delivery is N/A because the temporary relay does not alter product artifacts or release behavior and is removed.

## Open-source survey and implementation decision

N/A — this is a one-time GitHub configuration transfer, not a new product implementation. The relay uses the GitHub-hosted runner's preinstalled GitHub CLI and GitHub Actions secret contexts; no third-party Action or custom dependency is added.

## Verification plan

- Read canonical main workflow references and source organization secret names.
- Read back the target repository Actions secret names only.
- Inspect the Actions run conclusion and its names-only output.
- Confirm the temporary source token secret, relay workflow and branch are absent; confirm the fine-grained token has been revoked.
- No configuration values are captured in artifacts, task records, or logs.

## Branch / PR / implementation / evidence

- Temporary relay workflow: .github/workflows/_temporary-ios-secrets-relay.yml (remove after its single successful run).
- Branch / PR: pending.
- Actions run: pending.
- Target readback: pending.
- Cleanup: pending.
- Post-main product delivery: N/A — configuration-only relay, with no packaged app or release behavior change.

## Risks and next action

- Risk: a missing organization secret or insufficient token permission can fail the relay. The workflow fails closed and names only the unavailable secret.
- Next action: complete PR validation and run the one-time relay; then remove all temporary authorization and workflow resources and record exact results.
