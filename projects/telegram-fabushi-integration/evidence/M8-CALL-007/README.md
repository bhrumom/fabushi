# Evidence — M8-CALL-007

## Scope

MiniApp-defined Bot voice/video call programs and the independent teleprompter recording MiniApp.

## Current state

- Requirement source committed on feature branch.
- Atomic task record created.
- Open-source-first review completed.
- Messenger one-shot integration script syntax was repaired in `8539575525e7240fa6e0dfff9a21a285857c69e3`.
- The reviewed Messenger integration completed and wrote the product integration back to the branch in `48abcbbc1f1c1ab79b0fc0172f9c3ccbfd48a641`, removing the one-shot helper files afterward.
- Current-head CI is being re-triggered from a human/app-authored project-record update because GitHub marked the workflow-authored integration commit runs `action_required` without starting jobs.
- Status: `IN_PROGRESS` pending current-head required checks, protected merge-queue merge, and post-main packaged release evidence.

## Required evidence before closure

1. Feature branch implementation commit SHA(s).
2. Marketplace schema/unit/HTTP test results.
3. Rust/Host service-call and MCP-only regression results.
4. Desktop renderer typecheck/build results.
5. Electron Playwright evidence proving:
   - ordinary peer call still routes to WebRTC;
   - MiniApp Bot voice/video buttons route to the MiniApp-declared program;
   - AI-disabled deterministic IVR remains usable;
   - teleprompter video call camera/prompt/scroll/start/stop flow;
   - saved recording becomes a video message in the same Conversation;
   - permission/media/security failure cases are recoverable.
6. Current-head required GitHub Actions run/job IDs.
7. Protected PR merge SHA and canonical-main readback.
8. Exact-main packaged E2E screenshots, full operation video, Playwright trace/report/logs tied to SHA/version/run.
9. Verified GitHub Release tag, target main SHA and updater-compatible assets.

## Evidence policy

Passing assertions without the required screenshot/video/trace/report bundle do not close this task. Application-affecting code cannot use the documentation-only post-main N/A path.
