import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/data/chat/api/api_chat_repository.dart';

void main() {
  test('loads authenticated history and maps nullable author metadata',
      () async {
    final repository = ApiChatRepository(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/v1/fixtures/42/chat/messages');
        expect(request.url.queryParameters, {
          'limit': '25',
          'before_id': '30',
        });
        expect(request.headers['Authorization'], 'Bearer test-session');
        expect(request.headers['Accept'], 'application/json');
        return http.Response(
          jsonEncode({
            'items': [
              _messageJson(messageId: 10),
              _messageJson(
                messageId: 20,
                userId: null,
                username: null,
                avatarUrl: null,
                authorDeleted: true,
              ),
            ],
          }),
          200,
        );
      }),
      apiBaseUri: Uri.parse('https://api.example.test/v1'),
      requestHeaders: const {'Authorization': 'Bearer test-session'},
    );

    final messages = await repository.loadHistory(
      fixtureId: 42,
      beforeId: 30,
      limit: 25,
    );

    expect(messages.map((message) => message.messageId), [10, 20]);
    expect(messages.first.createdAt.isUtc, isTrue);
    expect(
      messages.first.avatarUrl,
      'https://api.example.test/v1/users/7/avatar',
    );
    expect(messages.last.displayUsername, 'Deleted user');
    expect(repository.cachedHistoryForFixture(42), orderedEquals(messages));
    expect(() => messages.clear(), throwsUnsupportedError);
  });

  test('merges older and newer pages into an immutable ordered cache',
      () async {
    var requestCount = 0;
    final repository = ApiChatRepository(
      client: MockClient((_) async {
        requestCount++;
        final items = requestCount == 1
            ? [_messageJson(messageId: 20), _messageJson(messageId: 30)]
            : [_messageJson(messageId: 10), _messageJson(messageId: 20)];
        return http.Response(jsonEncode({'items': items}), 200);
      }),
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      requestHeaders: const {},
    );

    await repository.loadHistory(fixtureId: 42);
    await repository.loadHistory(fixtureId: 42, beforeId: 20);

    final cached = repository.cachedHistoryForFixture(42);
    expect(cached.map((message) => message.messageId), [10, 20, 30]);
    expect(() => cached.clear(), throwsUnsupportedError);
  });

  test('supports the after cursor and rejects invalid query combinations',
      () async {
    var requestCount = 0;
    final repository = ApiChatRepository(
      client: MockClient((request) async {
        requestCount++;
        expect(request.url.queryParameters, {
          'limit': '100',
          'after_id': '0',
        });
        return http.Response(jsonEncode({'items': []}), 200);
      }),
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      requestHeaders: const {},
    );

    expect(
      await repository.loadHistory(fixtureId: 42, afterId: 0, limit: 100),
      isEmpty,
    );
    await expectLater(
      repository.loadHistory(fixtureId: 42, beforeId: 10, afterId: 5),
      throwsArgumentError,
    );
    await expectLater(
      repository.loadHistory(fixtureId: 0),
      throwsRangeError,
    );
    await expectLater(
      repository.loadHistory(fixtureId: 42, limit: 101),
      throwsRangeError,
    );
    expect(requestCount, 1);
  });

  test('rejects malformed ordering, identities, and HTTP failures', () async {
    final responses = [
      http.Response('Unavailable', 503),
      http.Response(
        jsonEncode({
          'items': [
            _messageJson(messageId: 2),
            _messageJson(messageId: 1),
          ],
        }),
        200,
      ),
      http.Response(
        jsonEncode({
          'items': [_messageJson(messageId: 3, fixtureId: 99)],
        }),
        200,
      ),
    ];
    var requestCount = 0;
    final repository = ApiChatRepository(
      client: MockClient((_) async => responses[requestCount++]),
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      requestHeaders: const {},
    );

    await expectLater(
      repository.loadHistory(fixtureId: 42),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      repository.loadHistory(fixtureId: 42),
      throwsFormatException,
    );
    await expectLater(
      repository.loadHistory(fixtureId: 42),
      throwsFormatException,
    );
    expect(repository.cachedHistoryForFixture(42), isEmpty);
  });
}

Map<String, Object?> _messageJson({
  required int messageId,
  int fixtureId = 42,
  int? userId = 7,
  String? username = 'supporter',
  String? avatarUrl = '/v1/users/7/avatar',
  bool authorDeleted = false,
}) =>
    {
      'message_id': messageId,
      'fixture_id': fixtureId,
      'user_id': userId,
      'username': username,
      'text': 'Come on City!',
      'created_at': '2026-09-18T12:34:56Z',
      'avatar_url': avatarUrl,
      'author_deleted': authorDeleted,
    };
