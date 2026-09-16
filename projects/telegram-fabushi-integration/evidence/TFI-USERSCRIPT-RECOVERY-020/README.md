# TFI-USERSCRIPT-RECOVERY-020 证据索引

状态：`IN_PROGRESS / SOURCE_LOCAL_VERIFIED / PARENT_DELIVERY_PENDING`

- 需求边界：`projects/telegram-fabushi-integration/source/2026-09-16-userscript-unbounded-stall-refresh.md`
- 任务记录：`projects/telegram-fabushi-integration/management/tasks/TFI-USERSCRIPT-RECOVERY-020-unbounded-stall-refresh.md`
- source commit：`205fc1266c779ea6addfd054ec3fd3df87ed3f4c`
- source candidate：v2.9.33，235095 bytes，SHA-256 `419a3eacdabe34b439cc71c2c934f5d7dea3a69a6ebaa50e76c7645da40f1986`
- source focused/full lightweight regression：`13/13`、`126/126`；syntax check 通过。
- parent candidate：Chrome `0.6.11`，bundled userscript 与 source 逐字节一致；parent CI/PR 尚未闭合。
- parent candidate commit：`fd5e3bdbbb423d1a32a12766f577c74adce80f41`。
- 待补证据：source canonical main/Release、parent PR/merge SHA、Chrome package 与 packaged simulated-user 分步 PNG/全程视频/trace/HTML report/native logs、post-main Release、Worker/catalog readback。
- 本机未构建或运行应用级 E2E；不得以本地结果替代 GitHub Actions 交付证据。
