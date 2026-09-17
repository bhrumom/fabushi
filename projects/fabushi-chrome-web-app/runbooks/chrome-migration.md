# Chrome migration runbook

1. Confirm exact-main Release, ZIP checksum and desktop package evidence. Stop active
   Computer Control operations and ask old Bridge to detach.
2. Keep user and automation tabs open. Install/update Fabushi 0.6.0 from the verified CI
   artifact. Do not copy old claim/generation state.
3. Open Fabushi Chrome, enumerate tabs, and claim only current title, URL and generation.
   Run snapshot/locator/CUA/navigation/download/create-retain-release/cleanup/detach checks
   and retain evidence IDs.
4. In each original profile open chrome://extensions, remove old ChatGPT Computer Control
   Bridge and official ChatGPT entries through the UI. Never edit Secure Preferences.
5. After inventory proves both absent, unregister com.fabushi.chatgpt_computer_control
   manifests/launchers and move only its Bridge-specific directory to Trash. Keep shared
   Computer Use MCP/native helpers and Fabushi runtime data.
6. Record profile, extension IDs, host paths, timestamp, screenshots and rollback outcome
   under evidence/CWA-006 and update task/milestone/acceptance state.
