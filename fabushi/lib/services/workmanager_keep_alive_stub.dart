/// Stub implementation for platforms that don't support WorkManager (Windows, macOS, Linux, Web)

Future<void> initializeWorkManager() async {
  // WorkManager not supported on this platform
}

Future<void> registerPeriodicTask() async {
  // WorkManager not supported on this platform
}

Future<void> cancelTask() async {
  // WorkManager not supported on this platform
}
