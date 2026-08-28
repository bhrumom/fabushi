# Fabushi Design System

## Visual theme
Calm, precise and lightweight. Messenger surfaces stay familiar and content-first; agent execution adds depth through motion and structured progress rather than ornamental chrome.

## Color roles
Use semantic tokens only. Primary accent communicates active agent/interactive state. Destructive, warning and success colors are reserved for real state. Never use gradients as a substitute for hierarchy.

## Typography
System-native sans-serif by default. Prioritize Chinese/Latin legibility, compact messenger density and clear hierarchy. Avoid oversized marketing typography inside product workflow surfaces.

## Spacing and layout
Use the 4/8px rhythm. Conversation content remains the primary axis. Workbench and Artifact UI should be progressively disclosed instead of creating permanent competing panels.

## Components and states
Interactive elements must expose hover, focus-visible, pressed, disabled, loading, success and error states where applicable. Bot/Agent state comes from real runtime events, not simulated busy timers.

## Motion
Motion communicates runtime state and spatial continuity. Entry is approximately 180–220ms, exit 120–160ms, strong ease-out. Respect reduced motion. Never animate from scale(0).

## Accessibility
Normal text targets WCAG AA contrast. Keyboard navigation, visible focus, semantic controls and screen-reader labels are required. Color must not be the only state indicator.

## Platform behavior
Desktop may expose richer hover and file interactions; mobile must preserve touch targets and constrained layouts; MiniApps remain sandbox/capability-bound and use the same semantic design tokens.

## Anti-patterns
Do not introduce generic AI purple gradients, excessive glassmorphism, fake terminal decoration, random card nesting, or a second visual language for generated artifacts. Do not copy Telegram/Grok/OpenDesign branding assets.
