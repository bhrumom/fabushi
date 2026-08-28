---
name: fabushi-design
zh_name: Fabushi 设计与 Artifact
description: Create or redesign Fabushi/Mahayana product UI, MiniApps, web prototypes, dashboards, documents and artifact surfaces using the canonical Fabushi design system.
triggers:
  - design fabushi ui
  - miniapp design
  - artifact preview
  - 设计小程序
fabushi:
  mode: prototype
  surface: web
  design_system:
    requires: true
  craft:
    requires: [typography, color, accessibility-baseline, animation-discipline, anti-ai-slop]
  critique:
    policy: required
---

# Workflow

1. Read `design-systems/fabushi/USAGE.md`, `DESIGN.md`, and `tokens.css`.
2. Read the requested craft references.
3. Inspect the existing product component and runtime state before changing UI.
4. Produce real project files, not an opaque canvas format.
5. For MiniApps, preserve existing WebMCP/capability and marketplace contracts.
6. Emit or update a typed artifact manifest with kind, entrypoint, preview and export capabilities.
7. Self-review hierarchy, state coverage, accessibility, motion and anti-slop rules.
8. Run the repository's relevant type/unit/E2E gates and retain evidence.
