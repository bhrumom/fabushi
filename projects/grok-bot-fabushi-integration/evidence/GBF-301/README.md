# GBF-301 Evidence — runtime behavior inventory

Canonical desktop call graph:

`MahayanaCoordinator.execute(RuntimeCommand)` -> `MahayanaHostTransport.execute` -> Electron `window.mahayana` -> per-method `feature.execute` edge -> `AppHost::feature_execute` -> `FeatureController::execute(FeatureCommand)` -> domain executor -> `MahayanaRuntime`/provider as required -> `HostEvent` -> renderer subscription.

The coordinator does not own an Agent backend; it tracks receipts, waits for typed events, and coordinates UI/product providers. Historical `frontend/.../grok-agent`, `grok-bot`, and `vendor/grok-bot-0.20.0` runtime paths are absent.

Direct AppHost marketplace/plugin lifecycle calls remain internal/native/mobile management surfaces; they are not exposed as desktop renderer Agent execution paths.
