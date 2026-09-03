# Runbooks

## Planned operational runbooks

1. Daily content cycle: discover verified changes -> capture/package -> review -> publish -> reconcile.
2. Capture failure: classify product failure vs runner/media failure; never publish success claim from failed run.
3. Privacy/security incident: freeze queue, revoke credentials if necessary, remove/correct affected content, preserve evidence, remediate and review.
4. Duplicate/runaway posting: activate kill switch, reconcile platform IDs, deduplicate queue and resume only after idempotency validation.
5. Platform outage/rate limit: pause adapter, preserve queue and retry within policy; use manual handoff if business-critical.
6. Weekly growth review: inspect content/feature/channel cohorts and choose experiments.
7. Monthly strategy review: platform mix, funnel quality, content fatigue, retention and product feedback themes.
