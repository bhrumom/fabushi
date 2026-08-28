# Source of Truth

1. `bhrumom/fabushi` canonical `main` is authoritative for implementation/CI/release facts.
2. This project folder is authoritative for MDA requirements, decisions, WBS and evidence indexes.
3. Existing Mahayana ownership contracts in `projects/mahayana-sovereign-runtime/` remain binding.
4. Existing Bot/Workbench contracts in `projects/grok-bot-fabushi-integration/` remain binding.
5. Upstream research baseline: `nexu-io/open-design@35edb37d60c8ec73e34174f1608f8833f461f8b4`, Apache-2.0.

## User requirement
Integrate all previously identified OpenDesign capabilities that improve Fabushi: design systems, design skills/templates, artifact live preview, runtime adapter registry concepts, isolated skill staging, craft rules, and exporters, while improving the existing product rather than adding a separate app.

## Provenance rule
Reuse Apache-2.0 code only when compatible and attribution is preserved; otherwise reimplement observable architecture/contract ideas inside Mahayana-owned boundaries. Never copy OpenDesign branding, cloud billing/service coupling, or create a second daemon/agent loop.
