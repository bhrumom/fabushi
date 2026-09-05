# VERSION-EXACT-HEAD-CHECKOUT execution evidence — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001`
- Requirement / Acceptance: `M6-PM-VEHC-R01` / `M6-PM-VEHC-A01`
- Product PR: `#2345`
- Product branch: `fix/tfi-m6-mainsafe-001-version-exact-head-checkout-001`
- Canonical base re-read before continuation: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture records PR / head: `#2340@9da26347e6de37a6576198b0f09d36928cbb1b0a`
- Architecture handoff comment: `5548081273`
- Pre-record implementation head: `76174474fec9b3681fea7e1960f0fc468093d94c`
- Pre-record implementation chain: `fd0c870928c766a41119759c6102d25a4d41cd5d -> 5c86cdc51fdabb5d4a3530de931becf1e97b75a4 -> 76174474fec9b3681fea7e1960f0fc468093d94c`
- Execution state at record creation: `FINAL-HEAD-AUTOMATIC-VALIDATION-PENDING`

## Continuation truth readback

The continuation did not restart implementation and did not create a second product PR. Live GitHub readback confirmed #2345 remained OPEN / UNMERGED on canonical base `dbf22b467d35c8af2a074896c355a41993c8c191`, with implementation head `76174474fec9b3681fea7e1960f0fc468093d94c` before this records-bearing commit.

The active main ruleset remains `main-merge-queue` and requires status `CI result`; the connected actor has no bypass. Execution does not enter the merge queue and does not merge.

## Implementation allowlist audit before records

The implementation/config diff before this records commit is exactly:

1. `.github/workflows/ci.yml`
2. `mobile/ios/project.yml`

All additional files introduced by this records commit are required to remain under `projects/telegram-fabushi-integration/**`.

Implementation facts re-read from #2345:

- `pull_request` canonical checkout explicitly resolves `github.event.pull_request.head.sha`;
- `merge_group` canonical checkout explicitly preserves `github.event.merge_group.head_sha`;
- the job fails closed by comparing the event-expected SHA with `git rev-parse HEAD` before the canonical script runs;
- `.github/scripts/assert-native-electron-canonical.sh` is byte-identical to canonical main and was not modified;
- `CI result` still directly requires `canonical-version-contract` and accepts only child result exactly `success`;
- `mobile/ios/project.yml` changes only `CURRENT_PROJECT_VERSION: 28 -> 29` semantically;
- `app-version.json`, Android/Electron/Cargo/dependencies, application/test source, other workflows, release configuration, ruleset and branch protection are unchanged by the implementation.

## Historical PR provenance — do not mutate

Live readback before the records commit confirmed all historical candidates remain OPEN / UNMERGED and provenance-only:

- #2341 head `2241c856fb3da498ac99ade89007fe01dd335183`
- #2342 head `570b874318bfe42406c6f46f51798baed8c89e48`
- #2343 head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`
- #2344 head `b60b8e2483333db21ca6cea068b7a1be9c0f4851`

They must not be closed, merged, rebased, retargeted or force-pushed by this task. #2343 synthetic-merge evidence is explicitly invalid as final acceptance evidence for #2345.

## Self-binding final-head evidence protocol

This file is intentionally written *before* the final automatic pull-request validation because a Git commit changes the product head. The commit that first contains this file and the companion execution handoff is the intended final records-bearing #2345 product head.

The exact final records/product SHA is therefore read back from GitHub only after the normal fast-forward push. Automatic `pull_request` Actions for that exact SHA must then finish without any subsequent Git commit. The immutable #2345 execution handoff comment records the exact SHA, run/job IDs, URLs and raw-log facts. That comment is part of the acceptance evidence but does not mutate the Git head.

Any later commit on #2345 invalidates that evidence and resets `M6-PM-VEHC-A01` to pending until the new head receives fresh automatic validation.

## Mandatory final-head acceptance after this records commit

All items are required on one unchanged final #2345 head:

1. final changed-file audit contains only `.github/workflows/ci.yml`, `mobile/ios/project.yml`, and `projects/telegram-fabushi-integration/**` records;
2. an automatic `pull_request` CI run is associated with that exact final head;
3. `Canonical version contract` is SUCCESS, not skipped/neutral/manual-only/rerun-only;
4. its raw log proves `expected_head=<final product head>` and `actual_head=<final product head>` from the explicit `git rev-parse HEAD` assertion;
5. raw log proves `bash .github/scripts/assert-native-electron-canonical.sh` executes only after that exact-head assertion and succeeds;
6. same-run `CI result` is SUCCESS and preserves exact-success propagation from `canonical-version-contract`;
7. Project portfolio governance and every other applicable automatic final-head run/job are truthful and green;
8. no historical SHA, synthetic merge SHA, sibling green run or manual invocation substitutes for these facts.

If any item fails or remains incomplete, execution must remain `BLOCKED` and must not hand off to code review.

## Downstream gates

Even after all final-head execution evidence passes, this task does **not** authorize merge queue entry, merge, test release or stable release. The only authorized next action is independent code review of the exact unchanged final #2345 product head. Protected `merge_group`, canonical-main readback, packaged test release and stable release remain downstream owners/gates defined by the frozen task contract.
