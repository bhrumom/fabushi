import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mahayana_sdk.dart';

class MahayanaCommandOutcome {
  const MahayanaCommandOutcome(
    this.message, {
    this.launchUri,
    this.session,
    this.loggedOut = false,
  });

  final String message;
  final Uri? launchUri;
  final Map<String, dynamic>? session;
  final bool loggedOut;
}

/// Slash-command adapter embedded by the Flutter desktop/mobile/web shell.
///
/// Commands are accepted only when the platform has bundled the local
/// Mahayana Runtime. The app never forwards Agent work to a cloud gateway.
class MahayanaCommandService {
  MahayanaCommandService();

  final MahayanaSdk _sdk = MahayanaSdk.instance;

  Future<Map<String, dynamic>> execute(
    Map<String, dynamic> command, {
    String? token,
  }) => _execute(command, token: token);

  Future<MahayanaCommandOutcome> run(String line, {String? token}) async {
    final parts = line.trim().split(RegExp(r'\s+')).toList();
    final name = parts.removeAt(0).toLowerCase();
    switch (name) {
      case '/help':
        return const MahayanaCommandOutcome(_help);
      case '/login':
        if (parts.firstOrNull?.toLowerCase() == 'poll') {
          parts.removeAt(0);
          if (parts.isEmpty) {
            throw const FormatException('用法：/login poll <state>');
          }
          final state = parts.first;
          final payload = await _execute({
            '@type': 'mahayana.auth.alipay.poll',
            'state': state,
          });
          if (payload['status'] == 'pending') {
            return MahayanaCommandOutcome(
              '支付宝仍在等待授权。完成后再次输入 /login poll $state',
            );
          }
          if (payload['needsRegistration'] == true &&
              payload['sessionStored'] != true) {
            throw StateError('该支付宝账号需要先完成大乘账号注册。');
          }
          return MahayanaCommandOutcome('支付宝账号登录成功。', session: payload);
        }
        if (parts.firstOrNull?.toLowerCase() == 'complete') {
          parts.removeAt(0);
          if (parts.isEmpty) {
            throw const FormatException('用法：/login complete <授权码> [state]');
          }
          final payload = await _execute({
            '@type': 'mahayana.auth.alipay.complete',
            'authCode': parts.removeAt(0),
            if (parts.isNotEmpty) 'state': parts.removeAt(0),
          });
          if (payload['needsRegistration'] == true &&
              payload['sessionStored'] != true) {
            throw StateError('该支付宝账号需要先完成大乘账号注册。');
          }
          return MahayanaCommandOutcome('支付宝账号登录成功。', session: payload);
        }
        final payload = await _execute({
          '@type': 'mahayana.auth.alipay.start',
          'platform': _alipayLoginPlatform,
        });
        final loginUrl = (payload['loginUrl'] ?? payload['authUrl'])
            ?.toString();
        if (loginUrl == null || loginUrl.isEmpty) {
          throw StateError('支付宝登录接口没有返回授权地址。');
        }
        final state = payload['state']?.toString();
        return MahayanaCommandOutcome(
          state != null && state.isNotEmpty && _alipayLoginPlatform == 'cli'
              ? '支付宝授权页已打开。授权完成后输入 /login poll $state 获取登录结果。'
              : '支付宝授权页已打开。授权完成后回到大乘，或输入 /login complete <授权码> 完成登录。',
          launchUri: Uri.parse(loginUrl),
        );
      case '/logout':
        await _execute(const {'@type': 'mahayana.auth.logout'}, token: token);
        return const MahayanaCommandOutcome('已退出大乘软件账号。', loggedOut: true);
      case '/status':
        final payload = await _execute(const {
          '@type': 'mahayana.auth.status',
        }, token: token);
        final loggedIn =
            payload['loggedIn'] == true ||
            (payload['success'] == true && payload['user'] != null);
        return MahayanaCommandOutcome(
          loggedIn ? '已登录大乘软件账号。' : '尚未登录。输入 /login 使用支付宝登录。',
        );
      case '/contacts':
        return _contacts(parts, token: token);
      case '/requests':
        return _requests(parts, token: token);
      case '/message':
        if (parts.length < 2) {
          throw const FormatException('用法：/message <联系人> <消息>');
        }
        final contact = parts.removeAt(0);
        final payload = await _execute({
          '@type': 'mahayana.messages.send',
          'contact': contact,
          'text': parts.join(' '),
          'clientRequestId':
              'flutter-cli-${DateTime.now().microsecondsSinceEpoch}',
        }, token: token);
        return MahayanaCommandOutcome(_format(payload));
      case '/messages':
        if (parts.isEmpty) {
          throw const FormatException('用法：/messages <联系人>');
        }
        final payload = await _execute({
          '@type': 'mahayana.messages.list',
          'contact': parts.first,
        }, token: token);
        return MahayanaCommandOutcome(_format(payload));
      case '/miniapp':
        if (parts.firstOrNull?.toLowerCase() == 'registry') {
          final payload = await _execute(const {
            '@type': 'mahayana.miniapps.registry',
          }, token: token);
          return MahayanaCommandOutcome(_format(payload));
        }
        if (parts.length < 2) {
          throw const FormatException(
            '用法：/miniapp <插件ID> <消息> 或 /miniapp registry',
          );
        }
        final miniAppId = parts.removeAt(0);
        final payload = await _execute({
          '@type': 'mahayana.miniapp.chat',
          'miniAppId': miniAppId,
          'message': parts.join(' '),
        }, token: token);
        return MahayanaCommandOutcome(
          (payload['message'] ?? payload['text'] ?? _format(payload))
              .toString(),
        );
      default:
        throw const FormatException('未知命令。输入 /help 查看大乘 CLI 命令。');
    }
  }

  Future<MahayanaCommandOutcome> _contacts(
    List<String> parts, {
    String? token,
  }) async {
    if (parts.isEmpty) {
      return MahayanaCommandOutcome(
        _format(
          await _execute(const {
            '@type': 'mahayana.contacts.list',
          }, token: token),
        ),
      );
    }
    final action = parts.removeAt(0).toLowerCase();
    if (action == 'search' && parts.isNotEmpty) {
      return MahayanaCommandOutcome(
        _format(
          await _execute({
            '@type': 'mahayana.contacts.search',
            'query': parts.join(' '),
          }, token: token),
        ),
      );
    }
    if (action == 'add' && parts.isNotEmpty) {
      final contact = parts.removeAt(0);
      return MahayanaCommandOutcome(
        _format(
          await _execute({
            '@type': 'mahayana.contacts.add',
            'contact': contact,
            if (parts.isNotEmpty) 'message': parts.join(' '),
          }, token: token),
        ),
      );
    }
    throw const FormatException(
      '用法：/contacts、/contacts search <关键词> 或 /contacts add <联系人>',
    );
  }

  Future<MahayanaCommandOutcome> _requests(
    List<String> parts, {
    String? token,
  }) async {
    if (parts.isEmpty) {
      return MahayanaCommandOutcome(
        _format(
          await _execute(const {
            '@type': 'mahayana.contacts.requests',
          }, token: token),
        ),
      );
    }
    if (parts.length == 2 && parts.first.toLowerCase() == 'accept') {
      return MahayanaCommandOutcome(
        _format(
          await _execute({
            '@type': 'mahayana.contacts.accept',
            'requestId': parts.last,
          }, token: token),
        ),
      );
    }
    throw const FormatException('用法：/requests accept <申请编号>');
  }

  Future<Map<String, dynamic>> _execute(
    Map<String, dynamic> command, {
    String? token,
  }) async {
    if (!_sdk.isAvailable) {
      throw StateError(
        '此平台未内置大乘 Runtime，命令已停止；不会回退到云端 Agent。'
        '${_sdk.loadError == null ? '' : ' ${_sdk.loadError}'}',
      );
    }
    return _sdk.execute(command);
  }

  String get _alipayLoginPlatform {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return defaultTargetPlatform.name;
    }
    return 'cli';
  }

  String _format(Map<String, dynamic> payload) {
    final data = payload['data'] is Map
        ? Map<String, dynamic>.from(payload['data'] as Map)
        : payload;
    final friends = data['friends'];
    if (friends is List) {
      if (friends.isEmpty) return '好友列表为空。';
      return friends
          .whereType<Map>()
          .map((item) {
            final value = Map<String, dynamic>.from(item);
            return '${value['displayName'] ?? value['username']} (@${value['username'] ?? '-'}) · ${value['id']}';
          })
          .join('\n');
    }
    final users = data['users'];
    if (users is List) {
      if (users.isEmpty) return '没有找到联系人。';
      return users
          .whereType<Map>()
          .map((item) {
            final value = Map<String, dynamic>.from(item);
            return '${value['displayName'] ?? value['username']} (@${value['username'] ?? '-'}) · ${value['id']} · ${value['status'] ?? 'available'}';
          })
          .join('\n');
    }
    final requests = data['requests'];
    if (requests is List) {
      if (requests.isEmpty) return '没有待处理的好友申请。';
      return requests
          .whereType<Map>()
          .map((item) {
            final value = Map<String, dynamic>.from(item);
            final from = value['fromUser'] is Map
                ? Map<String, dynamic>.from(value['fromUser'] as Map)
                : const <String, dynamic>{};
            return '#${value['id']} · ${from['displayName'] ?? from['username'] ?? '未知用户'} · ${value['message'] ?? ''}';
          })
          .join('\n');
    }
    final messages = data['messages'];
    if (messages is List) {
      if (messages.isEmpty) return '还没有消息。';
      return messages
          .whereType<Map>()
          .map((item) {
            final value = Map<String, dynamic>.from(item);
            return '${value['isOutgoing'] == true ? '我' : value['senderUsername'] ?? '对方'}：${value['text'] ?? ''}';
          })
          .join('\n');
    }
    if (payload['message'] is Map) {
      final message = Map<String, dynamic>.from(payload['message'] as Map);
      return '消息已发送，编号 #${message['id'] ?? '待同步'}。';
    }
    if (payload['status'] == 'accepted') return '好友申请已接受。';
    if (payload['status'] == 'pending') return '好友申请已发送。';
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static const _help = '''大乘 CLI 命令：
/login  使用支付宝登录
/login poll <state>
/login complete <授权码> [state]
/status  查看登录状态
/contacts  查看好友
/contacts search <关键词>
/contacts add <用户编号或用户名> [验证消息]
/requests  查看好友申请
/requests accept <申请编号>
/message <联系人> <消息>
/messages <联系人>
/miniapp <插件ID> <消息>
/miniapp registry
/logout  退出软件账号
普通文字会进入大乘 AI 对话。''';
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
