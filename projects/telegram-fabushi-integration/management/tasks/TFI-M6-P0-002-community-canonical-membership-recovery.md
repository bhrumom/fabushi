# TFI-M6-P0-002 — Community canonical membership and recovery projection

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M6-P0-002`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependency:** `TFI-M6-P0-001 REVIEW-PASS`; current task may be read/planned before then but implementation/acceptance is blocked.
- **Parallel condition:** no concurrent task may edit the same M6 membership/recovery paths.

## Objective
For Group/Channel backed by Community, make `CommunityState.members` the sole membership authority across live mutation, persisted restore, snapshots, event projection and Conversation participants.

## Exact implementation scope
- `native/mahayana-messaging/src/community.rs`: canonical member/status/admin/owner semantics.
- `native/mahayana-messaging/src/conversation.rs`: derived participant projection representation only.
- `native/mahayana-messaging/src/engine.rs`: member/admin/ban/leave/approval mutations and projection rebuild.
- `native/mahayana-messaging/src/service.rs`: command authorization/projection and recovery-facing service behavior.
- `native/mahayana-messaging/src/store.rs`: snapshot/load compatibility only if recovery proves stale participant vectors are persisted.
- existing M6 fixtures/tests under `native/mahayana-messaging/**` tied to these semantics.

## Implementation steps
1. After dependency review-pass, re-read canonical accepted M6-001 head and inventory every mutation/recovery path that writes participants or Community members.
2. Reconstruct Community-backed Conversation participants from `CommunityState.members`; never trust a stale raw participant vector as authority.
3. Project add/remove/approve/ban/leave/admin-role changes deterministically for both Group and Channel.
4. Block raw participant set/remove from mutating Community membership outside the authorized Community command path.
5. Define owner/admin downgrade, self-leave/owner-leave and no-orphan invariants.
6. Make legacy fixtures migrate/read compatibly or fail with an explicit repair error; never silently grant privilege.

## In scope
Canonical membership, recovery, participant projection, owner/admin/leave legacy invariants and tests.

## Out of scope
Admission mode policy, journal recipient model, protocol v3, renderer UI, local build/test.

## Acceptance by category
- **Unit:** member/status -> participant projection, owner/admin downgrade, ban/leave/self-leave and legacy conversion cases.
- **Contract:** before/after restart yields the same canonical member set and derived participants for Group and Channel; raw participant commands cannot bypass Community authority.
- **Integration:** service + engine + store snapshot/reload tests in GitHub Actions exercise mutation -> persist -> restore -> project.
- **E2E:** exact-main installable Group/Channel membership/restart smoke proves UI-visible membership does not drift after relaunch.
- **Security:** owner cannot be orphaned/reassigned through stale data; admin cannot elevate/downgrade beyond rights; banned/left actors are not restored as active.
- **Performance:** recovery remains bounded by existing snapshot/community size and introduces no polling/remote dependency; existing packaged messaging timings must not regress materially.

## Required write-back and evidence
Record actual dependency acceptance evidence, branch/commit/PR/review/CI/evidence/status/changelog in this file and TFI P0 WBS/acceptance/dependency/status/change/evidence. No planned value becomes passed.

Post-main closure requires exact-main installable package evidence: SHA, app version, platform, workflow run/job, journey/test ID, timestamp, full video, step screenshots, trace, HTML/native report, logs; pass/fail always-equivalent upload; 90-day target retention or recorded lower maximum. Any missing item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
