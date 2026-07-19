import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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

const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(),
);
const String _storageKeyName = 'fabushi.telegram.storage-key.v1';

Future<TelegramClientHandle> createTelegramRuntimeClient(
  TelegramRustRuntime runtime,
) async {
  final key = await _loadOrCreateStorageKey();
  final supportDirectory = await getApplicationSupportDirectory();
  final telegramDirectory = Directory(
    path.join(supportDirectory.path, 'telegram-rust'),
  );
  await telegramDirectory.create(recursive: true);
  final databasePath = path.join(telegramDirectory.path, 'state.sqlite3');
  try {
    final clientId = runtime.createPersistentClient(
      databasePath: databasePath,
      storageKey: key,
    );
    return TelegramClientHandle(clientId: clientId, persistent: true);
  } finally {
    key.fillRange(0, key.length, 0);
  }
}

Future<List<int>> _loadOrCreateStorageKey() async {
  final encoded = await _secureStorage.read(key: _storageKeyName);
  if (encoded != null && encoded.isNotEmpty) {
    final existing = base64Url.decode(encoded);
    if (existing.length != 32) {
      throw const TelegramRustRuntimeException(
        'telegram_storage_key_invalid',
        '系统安全存储中的 Telegram 数据密钥长度无效。',
      );
    }
    return existing;
  }

  final random = Random.secure();
  final key = List<int>.generate(32, (_) => random.nextInt(256));
  await _secureStorage.write(
    key: _storageKeyName,
    value: base64Url.encode(key),
  );
  return key;
}
