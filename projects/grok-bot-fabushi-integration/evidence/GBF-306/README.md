# GBF-306 Evidence — deterministic error/retry/timeout/concurrency

M2 Host-process fault tests prove generation isolation, deterministic restart/close and stale-child safety. FeatureHost rejects unknown interrupt operation IDs and emits a single interruption event for registered operations. Kernel resilience has explicit fail-closed lifecycle tests and `retry_policy_is_bounded_and_exponential`. GitHub Mahayana fast checks execute kernel, Agent bridge, workspace engine, MCP runtime, native Agent, protocol, direct Host and deterministic FeatureHost suites.
