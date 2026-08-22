# GBF-304 Evidence — session/resume/cancel lifecycle

Canonical lifecycle is owned by `mahayana-kernel::resilience::SessionRegistry`: explicit activate/pause/resume/begin_close/close/fail transitions; `pause_resume_close_and_reopen_are_explicit` and `invalid_lifecycle_transition_fails_closed` are covered by the existing Mahayana fast gate. FeatureHost cancellation checks that an operation is registered before forwarding interrupt to the runtime, removes operation ownership, and emits `operation.interrupted`.

Workspace checkpoints are provided by the sovereign workspace/native engine and represented back through the same runtime event model; no Grok checkpoint store is retained.
