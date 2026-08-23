# GBF-701 Evidence — IPC/Host threat model

`threat-model.json` defines seven trust boundaries and eight required threats. Each threat has an explicit mitigation and residual-risk statement. The security closure validator fails when the threat inventory is incomplete or when a mitigation boundary regresses.

Key enforced boundaries: no generic `fabushi:host` IPC, one FeatureHost Agent/tool path, target/generation-bound computer control, claim-bound browser tab control, one-time encrypted sensitive input, secret-safe diagnostics, safe attachment/model acquisition, and reference-only historical Grok source.
