# MDA-501 Typed artifact + preview

Status: in-progress

Objective: make generated outputs first-class typed artifacts in the existing Messenger/Workbench.

Implementation: `mahayana-artifact/v1` manifest; Artifact Studio listens to real Mahayana runtime events and extracts manifests; trusted Host preview reads only managed workspace files. Web/dashboard HTML receives restrictive CSP and renders in a sandboxed iframe. MiniApps never use the raw HTML path.

Acceptance: path traversal/symlink/network escape are denied; artifact cards expose real entrypoint/design/export metadata.

Verification: Node preview security tests + desktop typecheck/E2E. PR/CI evidence pending.
