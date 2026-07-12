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
    warning: '此平台尚未连接加密持久化存储。',
  );
}
