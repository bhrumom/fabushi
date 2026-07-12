import 'telegram_rust_runtime.dart';

class TelegramClientHandle {
  const TelegramClientHandle({
    required this.clientId,
    required this.persistent,
    this.warning,
  });

  final int clientId;
  final bool persistent;
  final String? warning;
}

Future<TelegramClientHandle> createTelegramRuntimeClient(
  TelegramRustRuntime runtime,
) async {
  return TelegramClientHandle(
    clientId: runtime.createClient(),
    persistent: false,
    warning: 'Web 端加密 IndexedDB 尚未接通，本次消息仅保留到页面关闭。',
  );
}
