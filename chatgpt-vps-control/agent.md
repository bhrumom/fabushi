# Device Disk-Space Safety Rules

These instructions apply to **all work performed through this MCP on every connected device**, including Linux servers, VPS hosts, macOS devices, Windows devices, deployment hosts, and any future device type.

They are mandatory and take precedence over convenience, speed, build/test habits, and cleanup-after-the-fact assumptions.

## CRITICAL: Never perform an operation that can exhaust device storage

1. **Every operation MUST be evaluated for disk-space impact before execution.**
   - Before any tool call, command, file write, download, copy, extraction, install, build, test, package, update, deployment, logging action, cache-producing action, database operation, container/image operation, or other action that may consume storage, determine whether it can materially increase disk usage.
   - Read-only operations still require this classification. If an operation is truly read-only and cannot materially increase persistent or temporary storage, the assessment may be trivial.
   - If disk impact is uncertain, treat the operation as potentially space-consuming and fail closed until it is understood.

2. **For every operation that may consume storage, check the relevant filesystem before executing it.**
   - Measure currently available bytes on every filesystem that may receive data, including the destination filesystem and any temporary/cache filesystem such as `/tmp`, `/var/tmp`, package-manager caches, build caches, container storage, application data directories, or alternate volumes.
   - Do not rely only on a percentage display; use available bytes when possible.
   - On Windows/macOS, use the equivalent filesystem/free-space inspection.

3. **Estimate peak additional storage, not only final artifact size.**
   The estimate MUST account for the worst reasonable peak footprint, including where applicable:
   - source + destination existing at the same time;
   - archive + extracted contents;
   - temporary/staging files;
   - package/dependency downloads;
   - compiler/build caches;
   - container layers/images;
   - logs and traces;
   - database journals/WAL/temp files;
   - update/rollback copies;
   - duplicated worktrees/checkouts;
   - partial downloads and retries;
   - atomic replacement requiring old and new versions simultaneously.

4. **Maintain a non-zero safety reserve at all times.**
   - An operation is prohibited if its estimated peak usage could reduce any affected filesystem below the configured device-specific reserve.
   - If no device-specific reserve is defined, preserve at least **the greater of 1 GiB or 5% of that filesystem's total capacity** after the estimated peak usage.
   - This reserve is a minimum safety floor, not a target. Use a larger margin for databases, production services, package installations, updates, builds, extraction, or workloads whose peak usage is difficult to predict.
   - Never plan an operation that intentionally relies on free space reaching zero or nearly zero.

5. **Fail closed when the estimate is unknown or unsafe.**
   - If available space cannot be measured reliably, peak usage cannot be bounded, or the operation could cross the reserve, do not execute it.
   - Split the work into bounded smaller steps, move the work to a device with sufficient space, use GitHub Actions/disposable runners, stream data instead of staging it, or otherwise redesign the operation.
   - Do not proceed on the assumption that space can be cleaned up later.

6. **Long-running or variable-growth operations MUST be monitored while running.**
   - Re-check free space at reasonable checkpoints when downloads, copies, updates, logs, data processing, extraction, builds, tests, containers, databases, or other operations can grow beyond the original estimate.
   - Stop or safely abort before the safety reserve is crossed.
   - Never wait for an `ENOSPC`, disk-full alert, failed database write, or service outage as the stopping condition.

7. **Low-space devices are recovery-only until safe headroom exists.**
   - If a relevant filesystem is already below the minimum reserve, prohibit new space-consuming work.
   - Only read-only diagnosis, explicitly authorized cleanup/recovery, deletion of known temporary artifacts, or other operations that reduce/avoid storage consumption may proceed.
   - Do not use cleanup as permission to immediately recreate large caches/build artifacts on a persistent device.

8. **Never delete user/service data merely to make an operation fit.**
   - Do not delete databases, user files, source repositories, backups, credentials, production state, or unrelated application data without explicit authorization.
   - Prefer avoiding the space-consuming operation, using an alternate volume/device, or using a disposable runner.
   - Cleanup must be limited to data that is known to be disposable or explicitly approved for deletion.

9. **Persistent devices are not build/cache dumping grounds.**
   - Follow the repository-wide rule that ordinary persistent devices are control/edit/deployment surfaces, not build surfaces.
   - Heavy compilation, packaging, dependency installation, browser/E2E downloads, Docker image construction, large test fixtures, and similar work belong on GitHub Actions or an explicitly designated disposable build runner.
   - Before deploying a prebuilt artifact to a persistent device, still perform the full peak-space assessment and preserve rollback headroom.

10. **Prefer bounded, space-efficient execution strategies.**
    - Stream instead of duplicating when possible.
    - Use atomic replacement without unnecessary extra copies.
    - Reuse already-present immutable artifacts where safe.
    - Avoid cloning large repositories when an API/file-level edit can accomplish the task.
    - Avoid uncontrolled logs, traces, caches, and temporary files.
    - Clean known temporary/staging data after successful completion, while preserving rollback material required by policy.

## Required preflight decision

Before executing any device operation, the agent MUST be able to answer:

1. Which filesystem(s) can this operation write to?
2. How much free space is currently available there?
3. What is the worst reasonable peak additional usage?
4. What safety reserve must remain?
5. Is `available_space - peak_additional_usage >= required_reserve` for every affected filesystem?

If the answer to question 5 is not confidently **yes**, the operation MUST NOT be executed.

## Examples

- A 2 GiB archive that expands to 8 GiB may require more than 10 GiB of peak headroom if both archive and extracted data coexist. Checking only the 2 GiB download size is prohibited.
- Updating a service by staging a new 1 GiB release while retaining the old 1 GiB release for rollback must account for both copies plus temporary extraction/download space.
- A build that may create a multi-gigabyte `target/`, `node_modules/`, DerivedData, Gradle cache, browser cache, or Docker layer set must not be run on a persistent device just because several GiB are currently free.
- A tiny text/config edit is allowed only after classifying it as bounded and confirming it cannot threaten the reserve.
- If a device has 45 GiB total capacity and no device-specific reserve, at least 2.25 GiB (5%) must remain after the estimated peak because that is greater than 1 GiB.

## Enforcement principle

**Disk-full is a preventable failure mode. The MCP agent must prevent it proactively. No task is considered successful if completing it risks reducing any affected device filesystem to zero or below the required safety reserve.**
