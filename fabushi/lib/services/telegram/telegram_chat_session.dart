import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../social_friend_service.dart';
import '../mahayana_command_service.dart';
import '../mahayana_sdk.dart';
import 'telegram_client_factory.dart';
import 'telegram_rust_runtime.dart';

class TelegramChatMessage {
  const TelegramChatMessage({
    required this.id,
    required this.chatId,
    required this.text,
    required this.sentAt,
    required this.isOutgoing,
    required this.deliveryState,
    required this.isDeleted,
  });

  final int id;
  final int chatId;
  final String text;
  final DateTime sentAt;
  final bool isOutgoing;
  final String deliveryState;
  final bool isDeleted;

  factory TelegramChatMessage.fromJson(Map<String, dynamic> json) {
    final content = Map<String, dynamic>.from(
      json['content'] as Map? ?? const <String, dynamic>{},
    );
    final data = Map<String, dynamic>.from(
      content['data'] as Map? ?? const <String, dynamic>{},
    );
    return TelegramChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      chatId: (json['chatId'] as num?)?.toInt() ?? 0,
      text: data['text']?.toString() ?? '',
      sentAt: DateTime.fromMillisecondsSinceEpoch(
        (json['dateUnixMs'] as num?)?.toInt() ?? 0,
      ),
      isOutgoing: json['isOutgoing'] == true,
      deliveryState:
          (json['deliveryState'] as Map?)?['state']?.toString() ?? 'sent',
      isDeleted: json['isDeleted'] == true,
    );
  }
}

class TelegramChatSummary {
  const TelegramChatSummary({
    required this.subtitle,
    required this.lastActivity,
    required this.unreadCount,
  });

  final String subtitle;
  final DateTime? lastActivity;
  final int unreadCount;
}

/// Owns the single Rust command/event client consumed by the Flutter chat UI.
///
/// Network acknowledgements deliberately remain pending until the MTProto
/// transport is connected; the UI therefore reflects the real core state and
/// never fabricates a successful remote delivery.
class TelegramChatSession extends ChangeNotifier {
  TelegramChatSession._();

  static final TelegramChatSession instance = TelegramChatSession._();

  final TelegramRustRuntime _runtime = TelegramRustRuntime.instance;
  final MahayanaCommandService _mahayana = MahayanaCommandService();
  final Set<int> _knownChats = <int>{};
  Future<void>? _initializing;
  int? _clientId;
  bool _persistent = false;
  String? _storageWarning;
  int _nextLocalMessageId = -1;
  Map<String, dynamic> _state = const <String, dynamic>{};
  Map<String, dynamic> _authorizationState = const <String, dynamic>{
    'type': 'waitParameters',
  };
  Map<String, dynamic> _transportStatus = const <String, dynamic>{};
  Object? _lastError;

  static const String _apiIdValue = String.fromEnvironment('TELEGRAM_API_ID');
  static const String _apiHash = String.fromEnvironment('TELEGRAM_API_HASH');

  bool get isReady => _clientId != null;
  bool get isPersistent => _persistent;
  String? get storageWarning => _storageWarning;
  Object? get lastError => _lastError;
  Map<String, dynamic> get authorizationState =>
      Map.unmodifiable(_authorizationState);
  Map<String, dynamic> get transportStatus =>
      Map.unmodifiable(_transportStatus);
  String get authorizationStateType =>
      _authorizationState['type']?.toString() ?? 'waitParameters';
  bool get telegramConfigurationAvailable =>
      int.tryParse(_apiIdValue) != null && _apiHash.isNotEmpty;
  bool get isTransportConnected =>
      _transportStatus['transportConnected'] == true;

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    try {
      await _runtime.initialize();
      final handle = await createTelegramRuntimeClient(_runtime);
      _clientId = handle.clientId;
      _persistent = handle.persistent;
      _storageWarning = handle.warning;
      await MahayanaSdk.instance.attachTelegramClient(
        clientId: handle.clientId,
      );
      await refresh();
      await refreshAuthorization();
      _lastError = null;
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  int chatIdForFriend(SocialFriendContact friend) {
    // Use 48 digest bits plus a namespace bit. The result remains below 2^53,
    // so JavaScript JSON represents it exactly while collision risk stays low.
    final bytes = sha256.convert(utf8.encode(friend.id)).bytes;
    var hash = 0;
    for (var index = 0; index < 6; index++) {
      hash = (hash * 256) + bytes[index];
    }
    return 0x1000000000000 | hash;
  }

  Future<void> upsertFriend(SocialFriendContact friend) async {
    await initialize();
    final chatId = chatIdForFriend(friend);
    final existing = _chat(chatId);
    if (_knownChats.contains(chatId) &&
        existing?['title'] == friend.displayName) {
      return;
    }
    final chat = <String, dynamic>{
      'id': chatId,
      'kind': 'private',
      'title': friend.displayName,
      'lastMessageId': existing?['lastMessageId'],
      'lastReadInboxMessageId': existing?['lastReadInboxMessageId'],
      'lastReadOutboxMessageId': existing?['lastReadOutboxMessageId'],
      'unreadCount': (existing?['unreadCount'] as num?)?.toInt() ?? 0,
      'pinnedMessageId': existing?['pinnedMessageId'],
      'notificationSettings':
          existing?['notificationSettings'] ??
          const <String, dynamic>{
            'muteUntilUnixMs': null,
            'soundId': null,
            'showPreview': true,
          },
      'isArchived': existing?['isArchived'] == true,
      'isMarkedUnread': existing?['isMarkedUnread'] == true,
      'draft': existing?['draft'],
      'folderIds': existing?['folderIds'] ?? const <int>[],
    };
    await _executeCommand(<String, dynamic>{
      'type': 'upsertChat',
      'chat': chat,
    });
    _knownChats.add(chatId);
  }

  Future<void> queueText(
    SocialFriendContact friend,
    String text, {
    int senderUserId = 1,
    String? token,
  }) async {
    final value = text.trim();
    if (value.isEmpty) return;
    await upsertFriend(friend);
    final now = DateTime.now().millisecondsSinceEpoch;
    final localMessageId = _nextLocalMessageId--;
    final clientRequestId = 'flutter-$now-${-localMessageId}';
    await _executeCommand(<String, dynamic>{
      'type': 'queueMessage',
      'chatId': chatIdForFriend(friend),
      'localMessageId': localMessageId,
      'senderUserId': senderUserId,
      'clientRequestId': clientRequestId,
      'dateUnixMs': now,
      'content': <String, dynamic>{
        'type': 'text',
        'data': <String, dynamic>{'text': value, 'entities': <dynamic>[]},
      },
      'replyToMessageId': null,
      'messageThreadId': null,
    });

    // Native shells use the Rust ABI; browser shells use the protocol-compatible
    // cloud gateway. Both reconcile the durable id into the local Rust core.
    try {
      final response = await _mahayana.execute(<String, dynamic>{
        '@type': 'mahayana.messages.send',
        'contact': friend.id,
        'text': value,
        'clientRequestId': clientRequestId,
      }, token: token);
      final message = response['message'];
      final serverMessageId = message is Map
          ? (message['id'] as num?)?.toInt()
          : null;
      if (serverMessageId == null || serverMessageId <= 0) {
        throw StateError('服务器没有返回有效的消息编号。');
      }
      await _executeCommand(<String, dynamic>{
        'type': 'acknowledgeMessage',
        'clientRequestId': clientRequestId,
        'serverMessageId': serverMessageId,
        'dateUnixMs': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (error) {
      await _executeCommand(<String, dynamic>{
        'type': 'failMessage',
        'clientRequestId': clientRequestId,
        'code': 'mahayana_delivery_failed',
        'retryable': true,
      });
      rethrow;
    }
  }

  Future<void> syncMessages(SocialFriendContact friend, {String? token}) async {
    await upsertFriend(friend);
    final response = await _mahayana.execute(<String, dynamic>{
      '@type': 'mahayana.messages.list',
      'contact': friend.id,
      'limit': 200,
    }, token: token);
    final data = response['data'];
    final rawMessages = data is Map ? data['messages'] : response['messages'];
    if (rawMessages is! List) return;
    final chatId = chatIdForFriend(friend);
    for (final raw in rawMessages.whereType<Map>()) {
      final message = Map<String, dynamic>.from(raw);
      final id = (message['id'] as num?)?.toInt();
      final senderUserId = (message['senderUserId'] as num?)?.toInt();
      final body = message['text']?.toString() ?? '';
      final createdAt = DateTime.tryParse(
        message['createdAt']?.toString() ?? '',
      );
      if (id == null || id <= 0 || senderUserId == null || body.isEmpty) {
        continue;
      }
      await _executeCommand(<String, dynamic>{
        'type': 'upsertRemoteMessage',
        'message': <String, dynamic>{
          'id': id,
          'chatId': chatId,
          'senderUserId': senderUserId,
          'dateUnixMs': (createdAt ?? DateTime.now()).millisecondsSinceEpoch,
          'editDateUnixMs': null,
          'content': <String, dynamic>{
            'type': 'text',
            'data': <String, dynamic>{'text': body, 'entities': <dynamic>[]},
          },
          'replyToMessageId': null,
          'messageThreadId': null,
          'deliveryState': const <String, dynamic>{'state': 'sent'},
          'reactions': const <dynamic>[],
          'isOutgoing': message['isOutgoing'] == true,
          'isPinned': false,
          'isDeleted': false,
        },
      });
    }
  }

  List<TelegramChatMessage> messagesForFriend(SocialFriendContact friend) {
    final chatId = chatIdForFriend(friend);
    final raw = _state['messages'] as List? ?? const <dynamic>[];
    final messages = raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => (item['chatId'] as num?)?.toInt() == chatId)
        .map(TelegramChatMessage.fromJson)
        .where((message) => !message.isDeleted && message.text.isNotEmpty)
        .toList();
    messages.sort((a, b) {
      final byDate = a.sentAt.compareTo(b.sentAt);
      return byDate == 0 ? a.id.compareTo(b.id) : byDate;
    });
    return messages;
  }

  TelegramChatSummary summaryForFriend(SocialFriendContact friend) {
    final messages = messagesForFriend(friend);
    final chat = _chat(chatIdForFriend(friend));
    final last = messages.isEmpty ? null : messages.last;
    return TelegramChatSummary(
      subtitle:
          last?.text ??
          (friend.username.isEmpty ? '已添加好友' : '@${friend.username}'),
      lastActivity: last?.sentAt,
      unreadCount: (chat?['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> refresh() async {
    final clientId = _clientId;
    if (clientId == null) return;
    final response = await _runtime.execute(clientId, const <String, dynamic>{
      '@type': 'telegram.getState',
    });
    _state = Map<String, dynamic>.from(
      response['state'] as Map? ?? const <String, dynamic>{},
    );
    final chats = _state['chats'] as Map?;
    if (chats != null) {
      for (final value in chats.values) {
        if (value is Map && value['id'] is num) {
          _knownChats.add((value['id'] as num).toInt());
        }
      }
    }
    final messages = _state['messages'] as List?;
    if (messages != null) {
      for (final value in messages.whereType<Map>()) {
        final id = (value['id'] as num?)?.toInt();
        if (id != null && id <= _nextLocalMessageId) {
          _nextLocalMessageId = id - 1;
        }
      }
    }
    notifyListeners();
  }

  Future<void> refreshAuthorization() async {
    final clientId = _clientId;
    if (clientId == null) return;
    final auth = await _runtime.execute(clientId, const <String, dynamic>{
      '@type': 'telegram.getAuthorizationState',
    });
    _authorizationState = Map<String, dynamic>.from(
      auth['authorizationState'] as Map? ?? const <String, dynamic>{},
    );
    _transportStatus = await _runtime.execute(clientId, const <String, dynamic>{
      '@type': 'telegram.getStatus',
    });
    notifyListeners();
  }

  Future<void> connectTelegram() async {
    await initialize();
    final clientId = _clientId;
    final apiId = int.tryParse(_apiIdValue);
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    if (apiId == null || _apiHash.isEmpty) {
      throw StateError(
        '请通过 TELEGRAM_API_ID 和 TELEGRAM_API_HASH 配置产品自己的 Telegram API 凭据。',
      );
    }
    try {
      await _runtime.execute(clientId, const <String, dynamic>{
        '@type': 'telegram.bootstrapTransport',
        'dcId': 2,
        'testMode': false,
      });
      await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.initializeConnection',
        'apiId': apiId,
        'deviceModel': _deviceModel,
        'systemVersion': 'Flutter ${defaultTargetPlatform.name}',
        'appVersion': const String.fromEnvironment(
          'APP_VERSION',
          defaultValue: '1.0.0',
        ),
        'systemLangCode': 'zh-Hans',
        'langPack': '',
        'langCode': 'zh-hans',
      });
      if (authorizationStateType == 'waitParameters') {
        final result = await _runtime.execute(clientId, const <String, dynamic>{
          '@type': 'telegram.executeAuthorizationCommand',
          'command': <String, dynamic>{'type': 'parametersAccepted'},
        });
        _authorizationState = Map<String, dynamic>.from(
          result['authorizationState'] as Map? ?? const <String, dynamic>{},
        );
      }
      await refreshAuthorization();
      _lastError = null;
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendAuthenticationCode(String phoneNumber) async {
    if (!isTransportConnected) await connectTelegram();
    final clientId = _clientId;
    final apiId = int.tryParse(_apiIdValue);
    if (clientId == null || apiId == null || _apiHash.isEmpty) {
      throw StateError('Telegram API configuration is unavailable.');
    }
    try {
      final result = await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.sendAuthenticationCode',
        'phoneNumber': phoneNumber.trim(),
        'apiId': apiId,
        'apiHash': _apiHash,
      });
      _authorizationState = Map<String, dynamic>.from(
        result['authorizationState'] as Map? ?? const <String, dynamic>{},
      );
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitAuthenticationCode(String code) async {
    final clientId = _clientId;
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    try {
      final result = await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.submitAuthenticationCode',
        'code': code.trim(),
      });
      _authorizationState = Map<String, dynamic>.from(
        result['authorizationState'] as Map? ?? const <String, dynamic>{},
      );
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitAuthenticationPassword(String password) async {
    final clientId = _clientId;
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    try {
      final result = await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.submitAuthenticationPassword',
        'password': password,
      });
      _authorizationState = Map<String, dynamic>.from(
        result['authorizationState'] as Map? ?? const <String, dynamic>{},
      );
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> submitRegistration({
    required String firstName,
    String lastName = '',
  }) async {
    final clientId = _clientId;
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    try {
      final result = await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.submitRegistration',
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
      });
      _authorizationState = Map<String, dynamic>.from(
        result['authorizationState'] as Map? ?? const <String, dynamic>{},
      );
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> beginUpdateSync() async {
    final clientId = _clientId;
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    try {
      final result = await _runtime.execute(clientId, const <String, dynamic>{
        '@type': 'telegram.beginUpdateSync',
      });
      _transportStatus = <String, dynamic>{
        ..._transportStatus,
        'updateState': result['state'],
      };
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }

  String get _deviceModel => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Fabushi Android',
    TargetPlatform.iOS => 'Fabushi iOS',
    TargetPlatform.macOS => 'Fabushi macOS',
    TargetPlatform.windows => 'Fabushi Windows',
    TargetPlatform.linux => 'Fabushi Linux',
    TargetPlatform.fuchsia => 'Fabushi',
  };

  Map<String, dynamic>? _chat(int chatId) {
    final chats = _state['chats'] as Map?;
    if (chats == null) return null;
    final direct = chats[chatId.toString()] ?? chats[chatId];
    return direct is Map ? Map<String, dynamic>.from(direct) : null;
  }

  Future<void> _executeCommand(Map<String, dynamic> command) async {
    final clientId = _clientId;
    if (clientId == null) {
      throw StateError('Telegram Rust runtime is not initialized.');
    }
    try {
      final result = await _runtime.execute(clientId, <String, dynamic>{
        '@type': 'telegram.executeCoreCommand',
        'command': command,
      });
      _state = Map<String, dynamic>.from(
        result['state'] as Map? ?? const <String, dynamic>{},
      );
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = error;
      notifyListeners();
      rethrow;
    }
  }
}
