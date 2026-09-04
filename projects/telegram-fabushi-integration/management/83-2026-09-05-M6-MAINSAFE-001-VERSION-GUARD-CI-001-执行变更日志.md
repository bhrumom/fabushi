# 83 — TFI-M6-MAINSAFE-001 VERSION-GUARD-CI-001 执行变更日志 — 2026-09-05

- Re-read live canonical `main@dbf22b467d35c8af2a074896c355a41993c8c191`, root `AGENTS.md`, portfolio/project authority, #2340 frozen task/governance records, and #2341 blocked implementation provenance/comments.
- Verified #2341 remains OPEN / UNMERGED at exact head `2241c856fb3da498ac99ade89007fe01dd335183`; blocker comment `5547296411` and architecture handoff `5547466413` remain intact. No #2341 mutation was performed.
- Re-read canonical `.github/workflows/ci.yml`, `.github/scripts/assert-native-electron-canonical.sh`, live ruleset `15857448`, and FCM ADR-0005.
- Confirmed protected main requires only `CI result`; pre-task `CI result` did not depend on a canonical version-contract child.
- Open-source/official review recorded GitHub Actions job dependency/required-status/merge-queue/manual-workflow semantics and existing GitHub-maintained `actions/checkout` / `actions/github-script` MIT provenance; no external code copied and no new dependency added.
- Created fresh branch `fix/tfi-m6-mainsafe-001-version-guard-ci-001` directly from canonical main; no #2340/#2341 lineage reused.
- Implementation commit `3aa3fac353671a2b7203f242ee12d1ff3119d345` modifies only `.github/workflows/ci.yml`.
- Added unconditional lightweight `Canonical version contract` job that sparse-checks out the unchanged canonical script's direct inputs and executes `bash .github/scripts/assert-native-electron-canonical.sh`.
- Added that child to `CI result.needs` and made `CI result` require its conclusion to be exactly `success`; unlike existing diff-selected jobs, `skipped` cannot satisfy this child.
- Left the existing changed-path classifier unchanged to preserve its unknown-non-doc `forceAll` behavior and all pre-existing domain selection semantics.
- Did not modify canonical version script, Electron/native/release workflows, rulesets, product/test source, `mobile/ios/project.yml`, `app-version.json`, Android, Cargo/dependencies, release/version semantics, or any prohibited downstream task.
- No local build/test/rustfmt/clippy/E2E was run. GitHub Actions exact-head evidence remains the acceptance source.
- Known bootstrap risk retained: canonical main itself still has the diagnosed iOS build-number drift; if the newly required child fails on that drift, execution must stop BLOCKED rather than modify the prohibited version file or weaken the gate.
