# ADR-0003: Marketplace security gate and automatic promotion

Status: accepted for CWA-009 design; implementation pending CI. Date: 2026-09-16.

## Decision

Treat a marketplace release as an immutable candidate until the self-hosted Fabushi security gate returns an authenticated, package-bound, signed all-pass result. GitHub remains the source and package host; the platform stores only metadata and the signed security report, not a binary CDN. On pass, a single D1 batch promotes the exact release to `approved/public`. On admission failure it remains unavailable. On recurring scan failure it is `revoked` and the catalog pointer moves to the newest remaining passed release.

The service is split into two trust zones:

1. `self-hosted gate`: polls the protected queue, downloads and verifies the GitHub package, safely unpacks it, performs ClamAV/Gitleaks/Syft/OSV checks and a no-network, read-only, resource-limited dynamic probe with no marketplace secrets.
2. `sign-and-report`: signs the exact package with the server-resident Cosign private key, verifies the bundle against the server-resident public key, then calls the protected Worker result endpoint. The Worker pins the public-key file digest and signer key ID.

The Worker never trusts a client-supplied “passed” boolean alone. It requires all named checks, the fixed security service identity and the exact configured server ID/source SHA, a Cosign bundle bound to the pinned server public-key digest, exact package digest/size, and the protected automation token. Public routes require the stored pass state and existing approved state.

## Alternatives rejected

- Publish immediately and scan later: rejected because a malicious package would be discoverable/installable during the scan window.
- Trust only a GitHub repository/release link: rejected because source hosting is transport/provenance, not a security verdict or catalog promotion event.
- Run untrusted plugin code on a credentialed release process: rejected because plugin code could exfiltrate publish or signing credentials.
- Treat a standard Docker container as the final multi-tenant guarantee: rejected; it is the initial CI probe boundary only. Firecracker or an equivalent dedicated micro-VM pool remains the production hardening path for arbitrary code.

## Provenance

Open-source-first research reviewed upstream `gitleaks/gitleaks` (MIT), `google/osv-scanner` (Apache-2.0), `anchore/syft` (Apache-2.0), `sigstore/cosign` (Apache-2.0), and `firecracker-microvm/firecracker` (Apache-2.0). No code was copied. The selected deployment shape is a self-hosted gate with container hardening and a documented micro-VM hardening path; GitHub Actions is not the security execution or publication plane.
