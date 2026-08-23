# GBF-801 Evidence — full-platform release-candidate regression

`gbf-release-candidate.yml` is the release-candidate coordinator. It dispatches the repository's seven canonical workflow gates against one exact RC branch/head SHA and refuses release-candidate acceptance unless every dispatched run concludes `success` on that same SHA:

1. CI
2. Electron desktop quality gate
3. Native mobile
4. Computer control security gate
5. GBF security closure
6. Mahayana fast checks
7. Messaging Product Gate

Run IDs, URLs, branch and SHA are written to the Actions summary. GBF-801 stays IN_PROGRESS until the final rebased stack is merged/ready and this coordinator proves all seven gates on one canonical candidate.
