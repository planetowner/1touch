import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/debug/mock_live_match.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'package:onetouch/screens/MatchScreen_tabs/livechat.dart';

import 'support/app_catalog.dart';

void main() {
  setUpAppCatalog();

  test('one live fixture changes clock, score, and events on refresh',
      () async {
    final repository = MockLiveFixtureRepository();
    final first = await repository.loadDetail(mockLiveMatchId);
    expect(repository.allFixtures, hasLength(1));
    expect(first.fixture.status, FixtureStatus.live);
    expect(first.fixture.homeScore, 1);
    expect(first.fixture.awayScore, 0);
    expect(first.clock?.minutes, 32);
    expect(first.events, hasLength(1));

    final second = await repository.refreshDetail(mockLiveMatchId);
    expect(second.clock?.minutes, 33);
    expect(second.fixture.awayScore, 0);

    final third = await repository.refreshDetail(mockLiveMatchId);
    expect(third.fixture.awayScore, 1);
    expect(third.events, hasLength(2));

    await repository.refreshDetail(mockLiveMatchId);
    final fifth = await repository.refreshDetail(mockLiveMatchId);
    expect(fifth.fixture.homeScore, 2);
    expect(fifth.events, hasLength(3));
    expect(repository.cachedDetail(mockLiveMatchId), same(fifth));
  });

  for (final size in [const Size(320, 700), const Size(430, 932)]) {
    testWidgets('live match refreshes without overflow at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mock = MockLiveMatch();
      await tester.pumpWidget(_app(
        MatchScreen(
          matchId: '$mockLiveMatchId',
          matchStatus: 'live',
          initialFixture: mock.fixtures.findById(mockLiveMatchId),
          repository: mock.fixtures,
          bettingRepository: mock.betting,
          chatRepository: mock.chat,
          chatSocket: mock.socket,
        ),
      ));
      await tester.pump();
      expect(find.text('MATCH INFO'), findsOneWidget);
      expect(mock.fixtures.cachedDetail(mockLiveMatchId)!.clock?.minutes, 32);

      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(mock.fixtures.cachedDetail(mockLiveMatchId)!.clock?.minutes, 33);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('test chat receives messages, echoes sends, and closes',
      (tester) async {
    final socket = MockLiveChatSocket();
    final repository = MockLiveChatRepository();
    await tester.pumpWidget(_app(LiveChatTab(
      matchId: mockLiveMatchId,
      repository: repository,
      socket: socket,
    )));
    await tester.pump();

    await tester.pump(const Duration(seconds: 8));
    expect(find.text('What a match!'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello from the test');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(find.text('Hello from the test'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(socket.lastSession?.isClosed, isTrue);
    expect(tester.takeException(), isNull);
  });
}

Widget _app(Widget child) => MaterialApp(
      locale: const Locale('en'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.whitetheme,
      home: Scaffold(body: child),
    );
