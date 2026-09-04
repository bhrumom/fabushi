# GBF P0 architecture — FAB-ARCH-P0-20260904

GBF defines observable trigger/progress/tool-result behavior and same-account device/App capability semantics. Runtime flow is `TFI directed message -> GBF trigger contract -> MSR durable Bot session -> MSR capability policy -> GBF-409/411 provider surface -> typed result -> TFI projection`.

GBF-409 remains device presence/pair/control authority; GBF-411 remains semantic Web/App MCP surface. GBF-508 adds only the Bot-facing behavior/routing seam. No Grok runtime, remote desktop identity system or direct provider->chat side channel is introduced.