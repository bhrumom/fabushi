# AAC-001 Evidence

- Open-source startup gate: reviewed `keycloak/keycloak` for mature RBAC concepts and `openmeterio/openmeter` for entitlement/metering concepts; adapted the separation pattern without adding dependencies.
- Implementation branch: `feat/fab-p0008-bhrum108-admin-unlimited`.
- Local targeted regression: 16/16 tests passed; Node syntax checks and `git diff --check` passed.
- PR `#2117` passed CI, Worker security config gate, Platform Control Plane, and Project portfolio governance, then merged through the merge queue.
- Canonical `main` SHA carrying the implementation: `52b7c10889e585660b7d2a22a40781c22f31b7a1`.
- Canonical-main Worker production deploy run `32813156280` completed successfully for SHA `52b7c10889e585660b7d2a22a40781c22f31b7a1`.
- Production AI runtime on `bhrum2`: `dacheng-ai-backend.service` at `/opt/dacheng-ai/current`, port `8788`.
- The production AI snapshot predates current-main module layout, so deploying current `server.js` alone failed on missing `codex_deepseek_adapter.js`; the attempt was immediately rolled back and `/health` was restored before proceeding.
- A compatibility hotfix was then applied against the actual production server: only an already-authenticated remote account whose normalized username is exactly `bhrum108` receives `role=super_admin`, `isAdmin=true`, `unlimitedUsage=true`, effective lifetime membership, token-budget bypass, and Codex adapter propagation.
- Production AI restart after the compatibility hotfix succeeded; `dacheng-ai-backend.service` is active and `/health` returns `status=ok`.
- Security negative test: unauthenticated `GET /api/ai/quota?username=bhrum108` returns `role=user`, `unlimited=false`, `monthlyLimit=1000`; a client-supplied username cannot grant the entitlement.
- Rollback backup for the production compatibility hotfix: `/opt/dacheng-ai/backups/20260825T053632Z/server.js`.
- PR `#2118` recorded the actual merge-queue canonical-main SHA in project history. A subsequent attempted registry restoration PR `#2119` was intentionally closed after the portfolio validator rejected mutation of the protected-main baseline; no governance bypass was used.
- Delivery caveat: the exact-SHA Electron desktop quality workflow contains pre-existing packaged-user-journey failures, and the native iOS job was still running at this evidence round. Therefore the repository task remains `in-progress` under the strict post-main delivery gate even though the requested Web and AI production authorization behavior has been deployed.
- Live positive verification using the real `bhrum108` bearer session is not recorded because no credential/token was exposed or copied into task evidence.
