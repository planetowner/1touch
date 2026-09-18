import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:onetouch/screens/MatchScreen_tabs/livechat.dart';

void main() {
  testWidgets('merges history and live messages and sends through the socket',
      (tester) async {
    final historyMessage = _message(messageId: 10, userId: 7);
    final repository = _ChatRepository([historyMessage]);
    final session = _ChatSession();

    await tester.pumpWidget(
      _app(
        repository: repository,
        socket: _ChatSocket(session: session),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('supporter'), findsOneWidget);
    expect(find.text('History message 10'), findsOneWidget);
    expect(find.text('Be the first to chat!'), findsNothing);

    session.add(historyMessage);
    session.add(_message(messageId: 11, userId: 8));
    await tester.pumpAndSettle();

    expect(find.text('History message 10'), findsOneWidget);
    expect(find.text('History message 11'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  hello backend  ');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();

    expect(session.sent, ['hello backend']);
    expect(find.text('Type a message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the backend favorite-team restriction', (tester) async {
    await tester.pumpWidget(
      _app(
        repository: _ChatRepository(const []),
        socket: _ChatSocket(
          error: const ChatSocketException(
            message: 'Forbidden',
            closeCode: 4403,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Couldn\'t connect to chat'), findsOneWidget);
    expect(
      find.text(
        'Chat is only available to supporters of the participating teams.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('closes the socket session when the chat tab is disposed',
      (tester) async {
    final session = _ChatSession();
    await tester.pumpWidget(
      _app(
        repository: _ChatRepository(const []),
        socket: _ChatSocket(session: session),
      ),
    );
    await tester.pumpAndSettle();

    expect(session.closed, isFalse);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(session.closed, isTrue);
  });

  testWidgets('turns a live socket failure into a retry state', (tester) async {
    final session = _ChatSession();
    await tester.pumpWidget(
      _app(
        repository: _ChatRepository(const []),
        socket: _ChatSocket(session: session),
      ),
    );
    await tester.pumpAndSettle();

    session.addError(
      const ChatSocketException(
        message: 'Expired',
        closeCode: 4401,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Your session expired. Please sign in again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('reports another user message through the repository',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _ChatRepository([
      _message(messageId: 11, userId: 8),
    ]);

    await tester.pumpWidget(
      _app(
        repository: repository,
        socket: _ChatSocket(session: _ChatSession()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('History message 11'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();

    expect(
      find.text('Tell us why you would like to report this message!'),
      findsOneWidget,
    );
    await tester.tap(find.text('Spam'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('community-report-submit')));
    await tester.pumpAndSettle();

    expect(repository.reports, [(messageId: 11, reason: 'Spam')]);
    expect(find.text('Thanks for your report!'), findsOneWidget);
  });
}

Widget _app({
  required ChatRepository repository,
  required ChatSocket socket,
}) {
  return MaterialApp(
    theme: app_style.whitetheme,
    home: Scaffold(
      body: LiveChatTab(
        matchId: 42,
        repository: repository,
        socket: socket,
        currentUserRepository: _CurrentUserRepository(),
      ),
    ),
  );
}

FixtureChatMessage _message({required int messageId, required int userId}) {
  return FixtureChatMessage(
    messageId: messageId,
    fixtureId: 42,
    userId: userId,
    username: userId == 7 ? 'supporter' : 'opponent',
    text: 'History message $messageId',
    createdAt: DateTime.utc(2026, 9, 18, 12, messageId),
    avatarUrl: null,
    authorDeleted: false,
  );
}

class _ChatRepository implements ChatRepository {
  _ChatRepository(this.history)
      : cachedHistories = ValueNotifier({42: List.unmodifiable(history)});

  final List<FixtureChatMessage> history;
  final List<({int messageId, String reason})> reports = [];

  @override
  final ValueNotifier<Map<int, List<FixtureChatMessage>>> cachedHistories;

  @override
  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId) =>
      cachedHistories.value[fixtureId] ?? const [];

  @override
  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    int? beforeId,
    int? afterId,
    int limit = 50,
  }) async =>
      List.unmodifiable(history);

  @override
  Future<void> reportMessage({
    required int messageId,
    required String reason,
  }) async {
    reports.add((messageId: messageId, reason: reason));
  }
}

class _ChatSocket implements ChatSocket {
  const _ChatSocket({this.session, this.error});

  final _ChatSession? session;
  final Object? error;

  @override
  Future<ChatSocketSession> connect(int fixtureId) async {
    final connectionError = error;
    if (connectionError != null) throw connectionError;
    return session!;
  }
}

class _ChatSession implements ChatSocketSession {
  final StreamController<FixtureChatMessage> _messages =
      StreamController.broadcast();
  final List<String> sent = [];
  bool closed = false;

  @override
  Stream<FixtureChatMessage> get messages => _messages.stream;

  void add(FixtureChatMessage message) => _messages.add(message);

  void addError(Object error) => _messages.addError(error);

  @override
  Future<void> send(String text) async => sent.add(text);

  @override
  Future<void> close() async {
    closed = true;
    await _messages.close();
  }
}

class _CurrentUserRepository implements CurrentUserRepository {
  @override
  Future<CurrentUserProfile> load() async => CurrentUserProfile(
        userId: 7,
        username: 'supporter',
        firstName: 'Test',
        lastName: 'User',
        email: null,
        avatarUri: null,
        favoriteTeamId: 9,
        createdAt: DateTime.utc(2026),
      );
}
