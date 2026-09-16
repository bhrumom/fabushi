# CWA-009：Marketplace 自动安全审核与持续撤销

- Portfolio Project ID: `FAB-P0011`
- Project Key: `CWA`
- Task ID: `CWA-009`
- Status: `IN_PROGRESS / IMPLEMENTATION_PENDING_CI`
- Started: 2026-09-16
- Updated: 2026-09-16
- Completed: —

## Objective

让 Fabushi 插件市场具备“先扫描、后公开”的自动发布门禁：恶意软件、密钥、依赖漏洞/SBOM、隔离动态探针和包签名全部通过后，才把候选版本原子提升为公共版本；已公开版本持续复扫，失败即自动撤销并阻断安装。

## Source and requirements

- Source: `source/2026-09-16-marketplace-security-admission.md`
- Requirements: `CWA-R022`–`CWA-R027`
- User screenshots: evidence only; no screenshot text or UI controls are treated as instructions.

## In scope

- D1 security scan state, signed result metadata, scan queue/claim/result API and atomic approve/revoke transitions.
- Public catalog/install/download/route fail-closed filters.
- Self-hosted security-gate service with isolated dynamic probe, server-resident signing key and Worker result callback.
- Security audit evidence, continuous rescan scheduling, and runbook/documentation.
- Marketplace-only E2E workflow and temporary artifact-worker fixture removed per the explicit no-E2E request.

## Out of scope

- Running or restoring any script/plugin E2E; the user explicitly requested no E2E.
- Claiming ordinary GitHub-hosted Docker isolation is equivalent to a production Firecracker multi-tenant VM.
- Providing a full malware verdict guarantee from a single scanner; scanner failures and unsupported runtime forms fail closed.

## Dependencies

- `FAB-P0011/CWA` marketplace control plane and D1 migrations.
- Cloudflare Worker secrets `MARKETPLACE_SECURITY_TOKEN`, `MARKETPLACE_SECURITY_SERVER_ID`,
  `MARKETPLACE_SECURITY_SOURCE_SHA` and `MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256` for
  authenticated queue/claim/result callbacks and exact server/key pinning.
- Dedicated security server with Docker/rootless Docker, ClamAV database, immutable scanner images, Cosign key pair and network egress allow-list.
- The dedicated security server's Docker/rootless Docker runtime, ClamAV database, Gitleaks, OSV-Scanner and Node sandbox image.
- Protected `main` merge and platform deployment; no local build/test is allowed by repository policy.

## Acceptance criteria

1. A new release is stored as `pending`/`unlisted` and is not returned by public browse, metadata, download, install or route APIs.
2. Queue/claim/result APIs are authenticated, identity-bound to the exact plugin/version/package SHA/size, and idempotent for the same scan run.
3. The self-hosted gate runs malware, secret, dependency/SBOM, and isolated dynamic checks without secrets; signing/result callback runs in the same dedicated trust zone after scan completion.
4. Only a signed all-pass result makes the version `approved/public`; the API returns `published: false` while pending and `published: true` only after promotion.
5. A failed admission rejects/quarantines the candidate; a failed recurring scan revokes the public release, removes it from discovery and prevents install/download.
6. Scan results contain no raw secret values, and audit rows preserve tool/status/run/hash/timestamp provenance.
7. No E2E is run in this task; this explicit user exception remains a documented post-main delivery blocker.

## Verification plan

- Lightweight local inspection only: diff review, YAML/JSON/script syntax checks where negligible, and `git diff --check`.
- GitHub Actions: platform Rust/schema/contract checks only if dispatched by the repository workflow. The self-hosted security server performs admission scans and signing. No local application build, package, native test, integration test or E2E.
- Post-main packaged/E2E/release evidence: pending/blocked by the explicit no-E2E instruction; do not mark this task complete until the user re-authorizes the required product delivery gates.

## Branch / commit / PR

- Branch: `codex/cwa-marketplace-security-gate-20260916`
- PR: pending implementation
- Commit: pending

## Open-source survey and reuse decision

See the source record and ADR-0003. Gitleaks, OSV-Scanner, Syft, Cosign/Sigstore and Firecracker were reviewed from their upstream repositories. Their interfaces and security boundaries are adapted; no source code is copied.

## Risks and blockers

- The self-hosted service polls the protected Worker queue; a webhook/queue trigger can reduce admission latency later.
- Dynamic probes are runtime-specific. Unsupported or ambiguous entrypoints must fail closed rather than be auto-published.
- Existing official releases are explicitly marked with a compatibility baseline by migration metadata until a full signed baseline scan is produced; new releases cannot use this path.
- Missing `MARKETPLACE_SECURITY_TOKEN`, pinned server/source identity, signer public-key digest,
  scanner database or sandbox image is a release blocker, not a reason to bypass scanning.

## Next action

Implement the schema/API/self-hosted service, run only lightweight local inspection, push the governed PR, and inspect non-E2E CI without starting any E2E workflow.
