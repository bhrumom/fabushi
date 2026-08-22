# GBF-401 Evidence — target-bound computer-control protocol

Version `1` adds `ComputerControlTarget` with target kind, device/window/browser identifiers and monotonic generation. Legacy local desktop commands safely default to protocol v1 / desktop / generation 0. Remote-mobile control is validated before any native action: protocol, target kind, active session, device id and generation must match. Unit tests cover legacy compatibility and target round-trip; FeatureHost test covers stale generation/wrong device rejection.
