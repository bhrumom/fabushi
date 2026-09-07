# WBS

| ID | Task | Acceptance | Status |
|---|---|---|---|
| CWA-001 | Project record | portfolio + scaffold committed | passed |
| CWA-002 | Complete Chrome app shell | UI + MV3 resource checks | superseded by CWA-005 |
| CWA-003 | Store prep | package script + docs | superseded by CWA-005 |
| CWA-004 | Validation | executable checks recorded | superseded by CWA-005 |
| CWA-005 | First-class Fabushi Chrome platform | independent Chrome app + desktop session bridge + existing-Chrome control + Web Store package | branch-verified; publisher smoke pending |

CWA-005 automated evidence: GitHub Actions `Chrome Extension Web Store` run `34119000281` on `d772c033b774eb4ccae6335d6a01c9ea8f233f9c` completed successfully after the final native-host reconnect fix. Earlier successful run `34118863314` on `cdbfcab02419c150e9fea47d692bd5faf64eb3ac` recorded the full first-class platform contract: Fabushi `0.3.0`, 10/10 focused tests passed, production ZIP file allowlist verified, and Web Store artifact uploaded. Final store-account upload, real packaged desktop/Chrome smoke capture, and review remain publisher-controlled gates rather than branch implementation work.
