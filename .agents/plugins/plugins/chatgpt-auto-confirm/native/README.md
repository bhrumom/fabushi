# Native runtime modules

- `Models.swift`: persisted approval, audit, and task queue data models.
- `ApprovalAccessibility.swift`: macOS Accessibility discovery and approval actions.
- `IPCAndCDP.swift`: Unix IPC and Chrome DevTools Protocol clients.
- `HiddenChatAndApproval.swift`: hidden Chat renderer lifecycle and background approval scanning.
- `ApprovalWatcher.swift`: approval watcher decisions, status, and lifecycle.
- `QueueState.swift`: task queue persistence, validation, prompts, and public status.
- `QueueWorker.swift`: hidden Quick Chat worker creation and task dispatch.
- `QueueMonitoring.swift`: task monitoring, continuation, completion, and watchdog recovery.
- `ChatScripts.swift`: JavaScript evaluated inside the hidden Chat renderer.
- `main.swift`: command-line parsing and command dispatch only.
