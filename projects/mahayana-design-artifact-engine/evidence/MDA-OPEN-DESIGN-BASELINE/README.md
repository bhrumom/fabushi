# OpenDesign upstream audit baseline

Repository: `nexu-io/open-design`
Pinned commit: `35edb37d60c8ec73e34174f1608f8833f461f8b4`
License observed at audit: Apache-2.0.

Reviewed architecture sources: `docs/agent-adapters.md`, `docs/design-systems.md`, `docs/skills-protocol.md`, bundled design-system/craft conventions.

Reuse decision: absorb compatible package/metadata/adapter/staging/artifact concepts into Fabushi-owned contracts. Do not embed OpenDesign daemon, desktop shell, branding, cloud billing/service ownership, or a competing model/tool/session loop. Direct verbatim code reuse is not required by the current implementation; provenance remains recorded because the architecture research materially informed the design.
