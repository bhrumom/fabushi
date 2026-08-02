# Mahayana GitHub-native MCP App template

This repository template creates one MCP App identity with one semantic version and a signed multi-artifact release. The common UI, native CLI artifacts, and web-wasm artifact are built from the same source commit and implement the same Tool Contract.

## Trust boundaries

- Fork pull requests run only `.github/workflows/pr-untrusted.yml` with a read-only token, no secrets, no OIDC, no deployment, and no reusable release artifact.
- Default-branch changes require Pull Requests, required checks, CODEOWNERS review, and stale approval dismissal through the repository ruleset.
- A merge does not publish. Only a protected GitHub Release or protected tag may invoke `.github/workflows/release-trusted.yml`.
- Formal releases use GitHub Actions OIDC, SPDX SBOMs, artifact attestations, immutable release assets, and exact source commit binding.
- A derived App must change the plugin ID, publisher namespace, signing identity, update channel, and release workflow identity.

## Developer flow

1. Create or link an Issue.
2. Fork the repository and create a non-default branch.
3. Run the same contract tests used by untrusted PR CI.
4. Review permission, Tool Contract, and artifact differences.
5. Create a Draft Pull Request only after explicit user confirmation.
6. Let maintainers and CODEOWNERS review; never push directly to the protected upstream default branch.

## Release assets

A trusted release builds:

- `common`
- `native-macos-arm64`
- `native-macos-x64`
- `native-windows-x64`
- `native-linux-x64`
- `web-wasm`

The release manifest records source repository ID, owner/name, default branch, exact commit, tree hash, SPDX license, artifact hashes, SBOMs, attestations, MCP Apps metadata, Tool Contract, and optional derivation lineage.
