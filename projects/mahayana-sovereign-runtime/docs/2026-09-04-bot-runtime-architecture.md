# MSR P0 architecture — FAB-ARCH-P0-20260904

Canonical flow: `Bot identity -> MSR session registry -> one durable Mahayana session -> context scope -> capability catalog -> policy/approval -> provider adapter -> typed result envelope`.

The session registry is authoritative for execution identity; TFI Messenger/MiniApp projections reference it but do not persist a second runtime identity. GBF device/App surfaces are providers, not execution owners. Provider-specific sessions, tools and transport details terminate behind MSR adapters.

Recovery restores the Bot-session mapping before accepting a turn. MiniApp install/update performs create-or-get, never blind create. Group/topic identifiers select context partitions inside the same session. Capability descriptors are filtered by current account, installation, pairing/control authorization and policy before model exposure.