# GBF-405 Evidence — browser target isolation

Migrated Fabushi-owned clean-room browser session/extension implementation. Managed sessions reject unsafe names/schemes, cannot shadow attached identities, and enforce claim-bound targets. Extension control uses `chrome.debugger` with instance id + ephemeral generation, claimed tab identity, per-tab queues, CDP target/session ids and child-session routing. Local focused tests passed for unsafe schemes, path containment, reserved identities, loopback claims, flattened child CDP sessions, extension authentication and reconnect.
