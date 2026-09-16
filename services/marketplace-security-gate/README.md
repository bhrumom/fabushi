# Fabushi marketplace security gate

This is the self-hosted admission and continuous-rescan worker for the Fabushi
marketplace. GitHub remains the source and immutable package host. This service
does not upload packages to its own storage and does not publish from GitHub
Actions.

The service performs this sequence:

1. Poll the protected Worker queue and claim one exact `pluginId`, `version`,
   package SHA-256 and byte size.
2. Download only GitHub-hosted artifacts, follow only an allow-listed GitHub
   redirect chain, and verify the digest and size before inspection.
3. Safely unpack tar/zip artifacts, rejecting traversal, links, special files,
   member-count limits and decompression bombs.
4. Run host ClamAV and isolated container checks: Gitleaks, Syft, OSV-Scanner,
   and the no-network Fabushi dynamic probe. Scanner containers are read-only,
   unprivileged, resource-limited, and receive no marketplace credentials.
5. Sign the exact primary package with the server-resident Cosign key, verify
   the signature locally, and return only bounded status/tool/version metadata
   plus the Cosign bundle.
6. The Worker atomically promotes an all-pass candidate to `approved/public`.
   A failed scheduled rescan revokes the active release and removes it from
   discovery/download/install paths.

The service is intentionally fail-closed. Missing scanner images, ClamAV
database, Cosign key, API token, immutable image digests, GitHub artifact
allow-list validation, or a scanner error cannot promote a release.

## Production prerequisites

- A dedicated Linux host or pool with Node.js 22, Python 3, Docker/rootless
  Docker, ClamAV (`clamscan` and `freshclam`), and Cosign installed.
- A dedicated service account and a private work directory with mode `0700`.
- Immutable, independently verified container image digests in the environment
  file. Tags alone are rejected by `server.mjs`.
- A server-only random `MARKETPLACE_SECURITY_TOKEN` matching the Worker secret.
- A server-only Cosign key pair. Compute the SHA-256 of the exact public-key
  file bytes and store that lowercase digest in the Worker secret
  `MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256`.
- Egress allow-listing for `api.ombhrum.com`, GitHub artifact hosts, and the OSV
  database endpoint. The plugin containers themselves have no network except
  OSV-Scanner's metadata lookup container, which never executes plugin code.
- For higher-risk multi-tenant workloads, replace the container dynamic probe
  with a dedicated Firecracker/equivalent micro-VM pool. Docker hardening here
  is a defense-in-depth boundary, not a claim of VM isolation.

## Install and operate

Copy `config.example.env` into the server's secret manager or a root-owned
environment file, replace every placeholder, install the systemd unit, and
start it only after the Worker secrets are configured. The service's `serverId`
and scanner revision SHA are included in every accepted audit result.

The service does not print scanner stdout/stderr, package contents, URLs,
tokens, secret matches, or report bodies. Operational logs contain only bounded
poll/item failure messages. On a process or callback failure, the Worker claim
becomes reclaimable after 30 minutes.

No E2E is part of this service. The user's explicit instruction to cancel script
and plugin E2E is preserved; this service's checks are admission/security scans,
not product E2E journeys.
