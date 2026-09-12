# Evidence index

CWA-007 evidence is pending: PR/commit/checks, 0.6.0 package hash/content
manifest, packaged login and same-account MCP screenshots, full video,
trace/report/logs, cross-account denial, logout offline proof, production
gateway deployment, Release/Web Store target SHA and assets.

Store evidence under evidence/CWA-006/ or link immutable Actions artifacts/releases. Every
bundle must name canonical main SHA, version, platform, workflow run/job, journey/test ID
and timestamp. Required bundles include Chrome ZIP/SHA/content manifest, desktop package
reports, step screenshots, complete video, Playwright trace/HTML report and platform logs.
Target retention is 90 days subject to repository policy. Passing assertions without this
bundle are insufficient.

PR evidence (not yet canonical-main): Chrome workflow `34667146375`, job `103481251591`,
artifact `10289707648` ([artifact](https://github.com/bhrumom/fabushi/actions/runs/34667146375/artifacts/10289707648)).
It contains the 0.5.0 ZIP, SHA/content manifests, labelled screenshots, complete WebM journey
video, Playwright trace/HTML report, native event log and timestamped report. Canonical-main
post-merge evidence is still required.
