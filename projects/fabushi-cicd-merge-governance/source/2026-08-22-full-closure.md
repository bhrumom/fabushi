# Continuation requirement — 2026-08-22

User continuation instruction:

> 继续推进fab-p0003直到全部完全落地才可以停止
>
> 不要停止直到所有完成

## Normalized impact

This continuation promotes the remaining roadmap work from optional follow-up into the active closure stream for FAB-P0003. The project is not complete when only the original FCM-001 optimization is merged. Closure requires:

1. FCM-002 CI latency observability/SLO;
2. FCM-004 canonical release-source gates for Apple and Google store delivery;
3. FCM-005 sensitive-path ownership/policy automation;
4. enterprise project-folder completeness;
5. live PR/CI/merge-queue evidence and canonical `main` verification.

No requirement in this source authorizes bypassing branch protection, CI, merge queue, signing safety, or secret-handling controls.
