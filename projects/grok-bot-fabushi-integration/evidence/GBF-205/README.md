# GBF-205 Evidence — native/edge IPC

- Shared edge descriptor is explicitly versioned.
- Main registers one IPC handler per declared method rather than a universal method dispatcher channel.
- Unknown/missing handlers, untrusted sender, handler exception, unknown event, subscription cleanup and dispose behavior have deterministic tests.
- Native desktop parity gate reports 156 methods / 28 events with every event produced.
