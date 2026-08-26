# Source intake

## 2026-08-26 user request

1. Synchronize and switch to current `main`.
2. Build a new MiniApp for batch watermark-free Douyin video download to local disk.
3. With the already-authenticated Douyin session, download every video shared by contact “小李子”.
4. Publish the MiniApp to the Fabushi marketplace and verify it is searchable and installable in the app.

Interpretation: only content visible to the authenticated user is in scope. The tool must not bypass CAPTCHA, access control, DRM, or creator permissions, and must not persist browser cookies in Git/release evidence.
