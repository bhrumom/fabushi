# GBF-804 Evidence — historical Grok branch archive governance

ADR-0006 records the release-time branch decision: `main` is the only build/runtime/release authority; `grok-bot-latest-source-fusion` at `7174a70567ae98ef534b0eebcbe66935f1471cc1` and `grok-bot-0.16-source-fusion` at `a8bd854b512a3eaf20be9518767ab593724d67dc` are retained only as read-only audit inputs. Wholesale merge/overwrite remains forbidden and blocked provenance remains reference-only.

`assert-gbf-release-readiness.py` scans production workflows and fails if either historical branch name is used by CI/package/release automation. Final GBF-804 closure additionally requires the post-release branch/ref audit; retention is intentionally preferred over destructive deletion because it preserves auditability without restoring runtime authority.
