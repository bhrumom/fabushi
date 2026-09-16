# Marketplace security gate runbook

## Provisioning

1. Create a dedicated Linux service account and a private work directory such as
   `/var/lib/fabushi-marketplace-security` with mode `0700`. Use rootless Docker
   where possible; do not grant the service access to application or user data.
2. Install Node.js 22, Python 3, Docker/rootless Docker, ClamAV (`clamscan` and
   `freshclam`) and Cosign. Refresh the ClamAV database before enabling the
   service.
3. Copy `services/marketplace-security-gate/config.example.env` into the server
   secret store. Replace every placeholder, including all scanner image tags with
   independently verified `@sha256:<64-hex>` digests. The service refuses mutable
   image tags.
4. Generate or import a dedicated Cosign key pair. Keep the private key and its
   password only on this server. Compute the SHA-256 of the exact public-key file
   bytes and configure the lowercase result as the Worker secret
   `MARKETPLACE_SECURITY_SIGNER_PUBLIC_KEY_SHA256`.
5. Configure the Worker secrets `MARKETPLACE_SECURITY_SERVER_ID` and
   `MARKETPLACE_SECURITY_SOURCE_SHA` to exactly match the deployed server
   environment. Generate a random `MARKETPLACE_SECURITY_TOKEN`; configure the
   same value as the Worker secret and in the server secret store. Never put it
   in GitHub, release assets, logs or plugin packages. Add all four Worker
   secrets through the protected Wrangler secret path and run the Worker
   security preflight.
6. Restrict egress to the Worker API, GitHub artifact/redirect hosts and OSV
   metadata endpoints. The scanner host must not accept public inbound requests.
   If Docker is rootful, treat its socket as root-equivalent and isolate the host;
   rootless Docker is preferred.

## Start and verify

Install `services/marketplace-security-gate/fabushi-marketplace-security-gate.service`
as a root-owned systemd unit, set the absolute checkout path in `ExecStart`, then
start it. Verify only health/status metadata: the service should poll the queue,
claim a candidate, download the immutable GitHub artifact, run all four checks,
sign and locally verify the exact primary package, and receive an accepted Worker
result. Do not copy raw scanner output into tickets or logs.

The Worker remains fail-closed while token, server identity/source SHA, public-key
digest, scanner database, image digest, package URL allow-list, claim, hash/size
or signature validation is missing. A pending candidate is not public during this
time.

## Revoke and rollback

For a failed admission, the Worker records `rejected` and keeps the candidate
unlisted. For a failed rescan of a public release, the Worker records `revoked`,
blocks discovery/download/install/route, and points the plugin at the newest
remaining approved + passed release. If the service is unavailable, do not
manually promote the release; fix the service and let the 30-minute stale claim
timeout make it reclaimable.

For an urgent incident, use the existing authenticated release revoke endpoint,
then rotate the Worker token and Cosign key as appropriate. Publish a new version
with a strictly newer version identifier after a clean scan; never overwrite an
immutable GitHub asset or reuse a package version.

## Key rotation

Deploy the new public-key digest and key ID in a coordinated compatibility change,
then deploy the server with the new private key and rescan the catalog. Keep the
old key only for verification of historical evidence, not new promotion. Remove
the old Worker pin after all active releases have a new accepted signature.

## Explicit no-E2E rule

This round must not run script/plugin E2E or product packaged E2E. Security
admission checks and this operational runbook are not substitutes for the normal
post-main product-delivery gate; the project remains incomplete until the user
explicitly re-authorizes any required product verification.
