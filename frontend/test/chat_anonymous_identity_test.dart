import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/chat/api/api_chat_mapper.dart';
import 'package:onetouch/data/chat/api/api_chat_response.dart';

void main() {
  final anonymousMessage = <String, Object?>{
    'message_id': 12,
    'fixture_id': 42,
    'nickname_en': 'ChaBumKun_WUE8',
    'nickname_ko': '차범근_WUE8',
    'is_mine': false,
    'author_deleted': false,
    'text': 'Hello',
    'created_at': '2026-09-30T12:00:00Z',
  };

  test('account metadata cannot override an anonymous author', () {
    final message = chatMessageFromApiResponse(ApiChatMessageResponse.fromJson({
      ...anonymousMessage,
      'user_id': 928371,
      'username': 'private-login',
      'display_name': 'Real Name',
      'avatar_url': '/v1/users/928371/avatar',
    }));
    expect(message.displayAuthor('ko'), '차범근_wue8');
    for (final language in ['en', 'ja', 'zh']) {
      expect(message.displayAuthor(language), 'chaBumKun_wue8');
    }
    expect(message.isMine, isFalse);
  });

  test('missing anonymous names never fall back to account names', () {
    for (final invalid in [
      {'nickname_en': null},
      {'nickname_ko': ''},
      {'author_deleted': true},
      {
        'author_deleted': true,
        'nickname_en': null,
        'nickname_ko': null,
        'is_mine': true
      },
    ]) {
      expect(
        () => chatMessageFromApiResponse(ApiChatMessageResponse.fromJson({
          ...anonymousMessage,
          ...invalid,
          'username': 'private-login',
        })),
        throwsFormatException,
      );
    }
  });
}
