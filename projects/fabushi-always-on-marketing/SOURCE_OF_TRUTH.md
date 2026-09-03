# Source of Truth

## Authority

1. User's latest explicit requirement after it is persisted in this project folder.
2. `projects/PORTFOLIO.json` and project identity policy for portfolio identity.
3. This project folder on GitHub `main`.
4. Accepted ADRs and current specs.
5. Live GitHub code, CI, releases and deployments for implementation facts.
6. External analytics/publishing systems for their own measured facts.
7. Conversation history.

## Original requirement

Create a long-term Fabushi marketing project that continuously broadcasts development progress and markets the product across self-media platforms. Use GitHub Actions to automatically test each feature and capture real video/screenshots; use those authentic assets as the source material for published marketing content.

## Evidence rule

A claim such as "feature X works" is publishable only when its package references objective evidence (CI run/test/build/release or an explicitly approved manual verification). Planned or prototype functionality must be labeled as such.

## Conflict handling

Do not silently rewrite history. Record requirement or design changes in `management/07-变更日志.md`, and record durable technical/governance decisions in `decisions/`.
