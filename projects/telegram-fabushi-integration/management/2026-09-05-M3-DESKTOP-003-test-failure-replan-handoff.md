# M3-DESKTOP-003 test-driven acceptance failure — architecture replan & execution handoff

- **Project**: `FAB-P0001 / TFI`
- **Architecture role**: planning / boundary / acceptance only
- **Date**: 2026-09-05
- **Architecture source baseline**: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- **Canonical main observed during replan**: `586a0952f17ab4b36dab9a69402b837968f5aa3f`
- **Product PR**: #2349, OPEN, exact head `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`
- **Test-driven failure records PR**: #2350, OPEN, head `20e0b5b38a97215cc3beb3bed1f67332e075aeee`
- **Binding test comment**: #2349 comment `5551040795`
- **Exact-head Electron run**: `33959034172` / #1673

## 1. Readback and factual boundary

Architecture re-read root governance, portfolio identity, TFI Source of Truth/PROJECT, M3-DESKTOP-003 and M3-DESKTOP-004 task cards, MSR (`FAB-P0005`) and GBF (`FAB-P0004`) Source of Truth / PROJECT boundaries, #2349/#2350 metadata/comments, exact run/job metadata, Linux raw job log, target `desktop/e2e/messenger.spec.ts`, `desktop/playwright.config.ts`, and `desktop/e2e/grok-visual-evidence.spec.ts`.

Observed facts:

1. Run `33959034172` is an exact-head workflow_dispatch run for `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`; Linux, macOS and Windows jobs completed success.
2. Successful packaged returning-user target attempts did **not** reproduce the reported ~1 minute delay. Observed renderer→list metrics were hundreds of milliseconds; diagnostic evidence retained `rootCauseClaim: null`.
3. Linux raw job `101287508113` proves the first packaged target attempt failed at the setup assertion because `seededConversationId == ""`; retry #1 passed. Therefore the green final job is not evidence of deterministic setup.
4. Target evidence includes timing/P0–P9 JSON and screenshot/trace material but does not contain a dedicated passing returning-user `.webm` or explicit app/main-process logs attributable to that same scenario. Separate Grok visual-evidence video is a different task/scenario and cannot satisfy M3-DESKTOP-003.
5. Existing `desktop/playwright.config.ts` already enables trace/video and writes to `test-results`; existing workflow diagnostics already uploads `desktop/test-results/**`. Existing Grok visual test demonstrates repository precedent for `page.screencast.start/stop`. A workflow change is therefore not justified merely to capture target evidence.
6. None of these facts establish a Mahayana/MSR or Grok/GBF product defect. Those projects remain read-only non-target boundaries.

## 2. Root-cause boundary decision

Current evidence supports **two separate diagnostic acceptance defects**, not a product-startup root cause:

- **A — scenario seed/setup nondeterminism**: the target can observe an empty conversation identity before its own history-seeding phase.
- **B — exact-scenario evidence-contract incompleteness**: accepted artifacts cannot reconstruct the same successful packaged target journey with dedicated video and app/main logs.

These must not be combined into a broad “make the desktop test green” task. A combined task would mix synchronization correctness with evidence infrastructure, make failure attribution ambiguous, and encourage product/workflow scope expansion.

`M3-DESKTOP-004` remains blocked because `M3-DESKTOP-003` has not produced a deterministic complete evidence package identifying a measured startup bottleneck. Non-reproduction plus `rootCauseClaim:null` is insufficient authorization to change product startup behavior.

## 3. Frozen atomic sequence

### 3.1 `M3-DESKTOP-003-SEED-001`

- **State**: `FROZEN / NEXT-ONLY-EXECUTABLE`
- **Purpose**: make the real returning-user scenario setup deterministic on the original attempt only.
- **Dependency**: existing 003 implementation + #2349/#2350/run `33959034172` failure evidence.
- **Implementation allowlist**: exactly `desktop/e2e/messenger.spec.ts`.
- **Additional records/evidence**: task-specific `projects/telegram-fabushi-integration/**` only.
- **Required semantics**: real login/create/select path; synchronize on an existing product-observable authority; do not fabricate persistence/localStorage/conversation identity; no fixed sleep as sole correctness; no retry increase, skip, weakened assertion or product semantic change.
- **Acceptance**: target seed/setup passes original attempt (`retry=0`) on exact final head, Linux no retry needed, 32-message seed + durable persistence + relaunch contract preserved, Windows/macOS remain green, no behavior/runtime/workflow change.
- **Failure stop**: any need for `desktop/src/**`, Electron main source, native/Host/auth/protocol/schema, workflow, dependency, version/release, MiniApp, MSR or GBF change returns to Architecture.

### 3.2 `M3-DESKTOP-003-EVIDENCE-001`

- **State**: `FROZEN / BLOCKED-BY-SEED-001`
- **Hard dependency**: independent test-driven acceptance `TEST-PASS` for `SEED-001`.
- **Purpose**: capture complete evidence for the exact target scenario without changing startup behavior.
- **Implementation allowlist**: exactly `desktop/e2e/messenger.spec.ts`.
- **Read-only precedent/config**: `desktop/e2e/grok-visual-evidence.spec.ts`, `desktop/playwright.config.ts`.
- **Required artifacts from the same original-attempt packaged target**: dedicated returning-user `.webm`; app/main-process stdout/stderr log file(s); existing timing JSON; existing P0–P9 JSON; screenshot(s); trace; scenario/task/exact-head/platform binding.
- **Acceptance**: Linux/macOS/Windows accepted target attempt exposes every required artifact; no Grok video substitution; evidence capture works on success; logs contain no secrets; existing `test-results/**` upload is sufficient; `diagnosticOnly:true` and `rootCauseClaim:null` preserved.
- **Failure stop**: workflow/product/native/runtime/config expansion is not authorized and returns to Architecture.

## 4. Parent and downstream gates

- Parent `M3-DESKTOP-003` remains `TEST-FAIL / BLOCKED` until both subtasks pass in order.
- Passing `SEED-001` only unlocks `EVIDENCE-001`; it does not authorize product fix/review/merge/release.
- Passing both subtasks returns the parent to Architecture for measured classification.
- Only if the complete deterministic evidence identifies a specific measured bottleneck may Architecture unfreeze a corresponding minimal `M3-DESKTOP-004` implementation task.
- If the ~1 minute delay remains non-reproduced with complete evidence, Architecture must define a new reproduction boundary (environment/state/dataset/timing) rather than guessing a startup fix.

## 5. Prohibited actions in this architecture round

No application/test/workflow code was modified by Architecture. No review, merge, rebase, retarget, force-push, protected queue, test release or stable release action is authorized or performed. Product PR #2349 and failure PR #2350 remain provenance/inputs.

## 6. Unique next action

Dispatch **only** `M3-DESKTOP-003-SEED-001` to the execution group, using its frozen task file as the authority. Do not start `EVIDENCE-001`, `M3-DESKTOP-004`, code review, test release or stable release in parallel.