import 'package:flutter_test/flutter_test.dart';
import 'package:global_dharma_sharing/services/social_friend_service.dart';
import 'package:global_dharma_sharing/services/telegram/telegram_chat_session.dart';

void main() {
  test('Rust text message JSON is rendered without a translation layer', () {
    final message = TelegramChatMessage.fromJson(<String, dynamic>{
      'id': -7,
      'chatId': 123,
      'dateUnixMs': 1720000000000,
      'content': <String, dynamic>{
        'type': 'text',
        'data': <String, dynamic>{
          'text': '来自 Rust 的消息',
          'entities': <dynamic>[],
        },
      },
      'deliveryState': <String, dynamic>{
        'state': 'pending',
        'clientRequestId': 'flutter-1',
      },
      'isOutgoing': true,
      'isDeleted': false,
    });

    expect(message.text, '来自 Rust 的消息');
    expect(message.deliveryState, 'pending');
    expect(message.isOutgoing, isTrue);
    expect(message.sentAt.millisecondsSinceEpoch, 1720000000000);
  });

  test('friend chat ids are stable and exactly representable on Web', () {
    const first = SocialFriendContact(id: 'friend-甲', displayName: '甲');
    const second = SocialFriendContact(id: 'friend-乙', displayName: '乙');
    final session = TelegramChatSession.instance;

    final firstId = session.chatIdForFriend(first);
    expect(firstId, session.chatIdForFriend(first));
    expect(firstId, isNot(session.chatIdForFriend(second)));
    expect(firstId, inInclusiveRange(0x1000000000000, 0x1ffffffffffff));
  });
}
