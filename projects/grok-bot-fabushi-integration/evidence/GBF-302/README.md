# GBF-302 Evidence — single Agent runtime

The desktop renderer Mahayana edge is restricted to `host.platform` plus `feature.*`. Agent commands enter `feature.execute` as typed `FeatureCommand` and are routed by the Rust FeatureHost. The CI convergence guard rejects any desktop renderer method outside this contract and rejects retired Grok runtime directories.

Existing FeatureHost CI test `deterministic_rust_backend_executes_every_declared_feature_journey` drives chat, install/open, approval, long task, interrupt, session clear and host close through one controller/event stream.
