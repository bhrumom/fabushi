# ACCEPTANCE

- [ ] A real multi-step Bot task streams ordered lifecycle/tool events and reaches a durable terminal state.
- [ ] Pause/stop/resume/redirect work from desktop and Web against the same canonical run.
- [ ] Tool policy, approval and audit are enforced; credentials are absent from transcripts/audit.
- [ ] File, URL, runnable HTML/MiniApp and patch/PR/release deliveries produce durable delivery records/cards with open/download and retry behavior.
- [ ] Restart/history recovery reconstructs steps, tool output, approvals/errors and delivery cards.
- [ ] Background/scheduled and subagent work remains correlated with the parent run.
- [ ] Queue state persists turnStartedAt, turnEndedAt, thinkingDurationSeconds/turnThinkingSeconds, Chat conversation ID, same-chat follow-up count and new-chat continuation count.
- [ ] Queue uses monotonic duration measurement and exactly enforces: unfinished + duration <1200s + same-chat follow-ups <2 => same Chat continuation; otherwise new Chat.
- [ ] Tests cover timer behavior, two same-chat continuations, >=1200s rollover, third-round rollover and abnormal recovery; CI is green.
- [ ] Task is registered in actions-inbox.json and can resume from revision/digest.
- [ ] PR is merged to canonical main and read back.
- [ ] Exact-main packaged desktop/Web and affected platform E2E gates are green with required evidence artifacts.
- [ ] Version/changelog updated and a GitHub Release/tag/assets target the accepted main SHA.

A plan, draft PR, source-only test or unpublished build does not satisfy acceptance.