import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/chat/api/api_chat_socket.dart';
import 'package:onetouch/data/chat/chat_socket.dart';

void main() {
  const token = '1234567890123456789012345678901234567890';

  test('uses wss and authenticates before accepting chat messages', () async {
    final connection = _FakeConnection();
    Uri? connectedUri;
    final socket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.1touch.football/v1'),
      sessionToken: () => token,
      connector: (uri) {
        connectedUri = uri;
        return connection;
      },
    );

    final connecting = socket.connect(42);
    await _waitFor(() => connection.sent.isNotEmpty);

    expect(
      connectedUri,
      Uri.parse('wss://api.1touch.football/v1/fixtures/42/chat'),
    );
    expect(jsonDecode(connection.sent.single as String), {'token': token});

    connection.addJson({'type': 'ready', 'fixture_id': 42});
    final session = await connecting;
    final nextMessage = session.messages.first;
    connection.addJson({
      'type': 'message',
      'message_id': 11,
      'fixture_id': 42,
      'user_id': 7,
      'username': 'supporter',
      'text': 'Come on City!',
      'created_at': '2026-09-18T12:34:56Z',
      'avatar_url': '/v1/users/7/avatar',
      'author_deleted': false,
    });

    final message = await nextMessage;
    expect(message.messageId, 11);
    expect(message.username, 'supporter');
    expect(
      message.avatarUrl,
      'https://api.1touch.football/v1/users/7/avatar',
    );
    await session.close();
    expect(connection.closedCode, 1000);
  });

  test('uses ws for an HTTP development API and sends trimmed text', () async {
    final connection = _FakeConnection();
    Uri? connectedUri;
    final socket = ApiChatSocket(
      apiBaseUri: Uri.parse('http://localhost:8000/v1/'),
      sessionToken: () => token,
      connector: (uri) {
        connectedUri = uri;
        return connection;
      },
    );
    final connecting = socket.connect(5);
    await _waitFor(() => connection.sent.isNotEmpty);
    connection.addJson({'type': 'ready', 'fixture_id': 5});
    final session = await connecting;

    await session.send('  hello  ');

    expect(connectedUri?.scheme, 'ws');
    expect(jsonDecode(connection.sent.last as String), {'text': 'hello'});
    await expectLater(session.send('   '), throwsArgumentError);
    await expectLater(
      session.send(List.filled(maxChatMessageLength + 1, 'x').join()),
      throwsArgumentError,
    );
    await session.close();
  });

  test('maps backend authorization close codes to typed errors', () async {
    final connection = _FakeConnection();
    final socket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      sessionToken: () => token,
      connector: (_) => connection,
    );
    final connecting = socket.connect(42);
    await _waitFor(() => connection.sent.isNotEmpty);
    connection.addJson({'type': 'ready', 'fixture_id': 42});
    final session = await connecting;
    final error = expectLater(
      session.messages,
      emitsError(
        isA<ChatSocketException>()
            .having((value) => value.closeCode, 'closeCode', 4403)
            .having((value) => value.isForbidden, 'isForbidden', isTrue),
      ),
    );

    await connection.finish(4403, 'Favorite team is not participating');

    await error;
  });

  test('reads the latest session at each connection', () async {
    String? currentToken;
    final connections = <_FakeConnection>[];
    final socket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      sessionToken: () => currentToken,
      connector: (_) {
        final connection = _FakeConnection();
        connections.add(connection);
        return connection;
      },
    );
    await expectLater(
      socket.connect(42),
      throwsA(isA<ChatSocketException>()
          .having((e) => e.closeCode, 'closeCode', 4401)),
    );
    expect(connections, isEmpty);
    for (final value in [token, 'a' * 40]) {
      currentToken = value;
      final connecting = socket.connect(42);
      final connection = connections.last;
      await _waitFor(() => connection.sent.isNotEmpty);
      expect(jsonDecode(connection.sent.single as String), {'token': value});
      connection.addJson({'type': 'ready', 'fixture_id': 42});
      await (await connecting).close();
    }
  });

  test('rejects malformed handshake frames and handshake timeouts', () async {
    final malformed = _FakeConnection();
    final malformedSocket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      sessionToken: () => token,
      connector: (_) => malformed,
    );
    final malformedConnect = malformedSocket.connect(42);
    await _waitFor(() => malformed.sent.isNotEmpty);
    malformed.addJson({'type': 'ready', 'fixture_id': 99});
    await expectLater(malformedConnect, throwsFormatException);

    final timedOut = _FakeConnection();
    final timeoutSocket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      sessionToken: () => token,
      connector: (_) => timedOut,
      handshakeTimeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      timeoutSocket.connect(42),
      throwsA(isA<TimeoutException>()),
    );
    expect(timedOut.closedCode, 1001);
  });

  test('rejects invalid fixture IDs and session-token lengths', () async {
    await expectLater(
      ApiChatSocket(
        apiBaseUri: Uri.parse('https://api.example.test/v1/'),
        sessionToken: () => 'short',
        connector: (_) => _FakeConnection(),
      ).connect(42),
      throwsArgumentError,
    );
    final socket = ApiChatSocket(
      apiBaseUri: Uri.parse('https://api.example.test/v1/'),
      sessionToken: () => token,
      connector: (_) => _FakeConnection(),
    );
    await expectLater(socket.connect(0), throwsRangeError);
  });
}

Future<void> _waitFor(bool Function() condition) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(Duration.zero);
  }
  throw StateError('Condition was not reached.');
}

class _FakeConnection implements ChatSocketConnection {
  final StreamController<Object?> _frames = StreamController<Object?>();
  final List<Object> sent = [];
  int? closedCode;
  String? closedReason;

  @override
  Future<void> get ready async {}

  @override
  Stream<Object?> get stream => _frames.stream;

  @override
  int? get closeCode => closedCode;

  @override
  String? get closeReason => closedReason;

  @override
  void add(Object data) => sent.add(data);

  void addJson(Map<String, Object?> value) => _frames.add(jsonEncode(value));

  Future<void> finish(int code, String reason) async {
    closedCode = code;
    closedReason = reason;
    await _frames.close();
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closedCode = closeCode;
    closedReason = closeReason;
  }
}
