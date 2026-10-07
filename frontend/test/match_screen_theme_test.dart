import 'dart:async';

import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/data/chat/chat_socket.dart';
import 'package:onetouch/data/fixtures/mock/mock_fixture_repository.dart';
import 'package:onetouch/data/standings/mock/mock_standing_repository.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/fixture_chat_message.dart';
import 'package:onetouch/screens/MatchScreen.dart';
import 'support/fake_betting_repository.dart';
import 'support/test_match_analysis_repository.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

void main() {
  setUpAppCatalog();
  Future<void> pumpMatch(
    WidgetTester tester, {
    required ThemeData theme,
    required Size size,
    required String matchId,
    required String matchStatus,
    ChatRepository? chatRepository,
    ChatSocket? chatSocket,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final fixtureCatalog = MockFixtureRepository();
    final fixture = fixtureCatalog.findById(int.parse(matchId))!;
    final repository = MockFixtureRepository(
      fixtureDetails: [
        FixtureDetail(
          fixture: fixture,
          venueName: null,
          expectedGoals: null,
          playerExpectedGoals: const [],
          shots: const [],
          events: const [],
          statistics: const [],
          lineups: const [],
          formations: const [],
          coaches: const [],
          pressure: [
            FixturePressurePoint(
              teamId: fixture.homeTeamId,
              minute: 10,
              pressure: 0.7,
            ),
            FixturePressurePoint(
              teamId: fixture.awayTeamId,
              minute: 20,
              pressure: 0.4,
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MatchScreen(
          matchId: matchId,
          matchStatus: matchStatus,
          initialFixture: fixture,
          repository: repository,
          bettingRepository: FakeBettingRepository(),
          analysisRepository: TestMatchAnalysisRepository(
            MatchTacticalAnalysis(
                fixtureId: fixture.fixtureId,
                available: false,
                home: null,
                away: null),
            MatchShotMap(
                fixtureId: fixture.fixtureId,
                available: true,
                homeCount: 0,
                awayCount: 0,
                shots: const []),
          ),
          standingRepository: MockStandingRepository(),
          chatRepository: chatRepository,
          chatSocket: chatSocket,
        ),
      ),
    );
    await tester.pump();
  }

  BoxDecoration boxDecoration(WidgetTester tester, Key key) {
    final container = tester.widget<Container>(find.byKey(key));
    return container.decoration! as BoxDecoration;
  }

  Color decorationColor(WidgetTester tester, Key key) =>
      boxDecoration(tester, key).color!;

  testWidgets('upcoming match uses responsive light surfaces', (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
      matchId: '20100001',
      matchStatus: 'upcoming',
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('match-screen-scaffold')),
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));

    expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
    expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
        scaffold.backgroundColor);
    expect(backIcon.color, app_style.AppPalette.black);
    expect(
      decorationColor(tester, const ValueKey('match-tab-0')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-tab-1')),
      app_style.AppPalette.lightGreyBox,
    );
    final firstTabRect = tester.getRect(
      find.byKey(const ValueKey('match-tab-0')),
    );
    final secondTabRect = tester.getRect(
      find.byKey(const ValueKey('match-tab-1')),
    );
    expect(firstTabRect.height, 34);
    expect(secondTabRect.height, 34);
    expect(secondTabRect.left - firstTabRect.right, 8);
    expect(
      boxDecoration(tester, const ValueKey('match-tab-0')).borderRadius,
      BorderRadius.circular(16),
    );
    expect(
      tester.widget<Text>(find.text('MATCH PREVIEW')).style!.color,
      app_style.AppPalette.black,
    );
    expect(
      tester.widget<Text>(find.text('HEAD TO HEAD')).style!.color,
      app_style.AppPalette.black,
    );
    final homeTeam = tester.getRect(
      find.byKey(const ValueKey('match-preview-home-team')),
    );
    final awayTeam = tester.getRect(
      find.byKey(const ValueKey('match-preview-away-team')),
    );
    expect(homeTeam.left, 24);
    expect(homeTeam.width, 72);
    expect(awayTeam.width, 72);
    expect(awayTeam.right, 320 - 24);
    for (final key in [
      const ValueKey('match-preview-round-label'),
      const ValueKey('match-preview-date-label'),
      const ValueKey('match-preview-time-label'),
    ]) {
      final text = tester.widget<Text>(find.byKey(key));
      expect(text.style!.fontSize, Body2.style.fontSize);
      expect(text.style!.fontWeight, Body2.style.fontWeight);
    }
    expect(
      decorationColor(tester, const ValueKey('match-betting-card')),
      app_style.AppPalette.white,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('match-betting-card')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    );
    final bettingCard = tester.getRect(
      find.byKey(const ValueKey('match-betting-card')),
    );
    final bettingHomeTeam = tester.getRect(
      find.byKey(const ValueKey('match-betting-home-team')),
    );
    final bettingAwayTeam = tester.getRect(
      find.byKey(const ValueKey('match-betting-away-team')),
    );
    expect(bettingHomeTeam.left - bettingCard.left, 16);
    expect(bettingHomeTeam.width, 40);
    expect(bettingAwayTeam.width, 40);
    expect(bettingCard.right - bettingAwayTeam.right, 16);
    final outcomeGroup = tester.getRect(
      find.byKey(const ValueKey('match-betting-outcome-group')),
    );
    final winBox = tester.getRect(
      find.byKey(const ValueKey('match-betting-odds-box-0')),
    );
    final drawBox = tester.getRect(
      find.byKey(const ValueKey('match-betting-odds-box-1')),
    );
    final lossBox = tester.getRect(
      find.byKey(const ValueKey('match-betting-odds-box-2')),
    );
    expect(drawBox.left - winBox.right, 8);
    expect(lossBox.left - drawBox.right, 8);
    expect(
      outcomeGroup.left - bettingHomeTeam.right,
      closeTo(bettingAwayTeam.left - outcomeGroup.right, 0.01),
    );
    expect(
      boxDecoration(
        tester,
        const ValueKey('match-betting-card'),
      ).boxShadow,
      app_style.lightModeCardShadows,
    );
    expect(
      decorationColor(tester, const ValueKey('match-preview-standing-header')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-preview-standing-body')),
      app_style.AppPalette.lightGreyBox,
    );
    expect(
      tester
          .widget<Container>(
            find.byKey(const ValueKey('match-preview-standing-body')),
          )
          .padding,
      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    );
    final standingClubHeader = tester.widget<Text>(
      find.byKey(const ValueKey('match-preview-standing-club-header')),
    );
    expect(standingClubHeader.style!.fontSize, Body2.style.fontSize);
    expect(standingClubHeader.style!.fontWeight, Body2.style.fontWeight);
    expect(standingClubHeader.style!.color, app_style.AppPalette.black);

    await tester.ensureVisible(find.text('PLACE A BET'));
    await tester.pump();
    await tester.tap(find.text('PLACE A BET'));
    await tester.pumpAndSettle();
    expect(
      decorationColor(tester, const ValueKey('match-betting-modal')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('match-nested-scroll')),
      const Offset(0, 1000),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-120, 0),
    );
    await tester.pump();
    await tester.tap(find.text('HEAD TO HEAD'));
    await tester.pump();
    await tester.pump();
    expect(
      decorationColor(tester, const ValueKey('match-tab-0')),
      app_style.AppPalette.lightGreyBox,
    );
    expect(
      decorationColor(tester, const ValueKey('match-tab-1')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-h2h-wdl-card')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('past match tabs use light cards on a tall phone', (
    tester,
  ) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(430, 932),
      matchId: '19200001',
      matchStatus: 'past',
    );

    expect(
      decorationColor(tester, const ValueKey('match-momentum-card')),
      app_style.AppPalette.white,
    );

    await tester.tap(find.text('HEAD TO HEAD'));
    await tester.pump();
    await tester.pump();
    expect(
      decorationColor(tester, const ValueKey('match-h2h-wdl-card')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-h2h-bets-card')),
      app_style.AppPalette.white,
    );

    await tester.drag(
      find.byKey(const ValueKey('match-tab-scroll')),
      const Offset(-180, 0),
    );
    await tester.pump();
    await tester.tap(find.text('ANALYSIS'));
    await tester.pumpAndSettle();
    expect(
      decorationColor(tester, const ValueKey('match-analysis-attack-card')),
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark match surfaces retain their existing palette', (
    tester,
  ) async {
    await pumpMatch(
      tester,
      theme: app_style.darktheme,
      size: const Size(430, 932),
      matchId: '20100001',
      matchStatus: 'upcoming',
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('match-screen-scaffold')),
    );
    expect(scaffold.backgroundColor, app_style.AppPalette.black);
    expect(
        tester.widget<SliverAppBar>(find.byType(SliverAppBar)).backgroundColor,
        scaffold.backgroundColor);
    expect(
      decorationColor(tester, const ValueKey('match-betting-card')),
      app_style.AppPalette.darkGrey,
    );
    expect(
      boxDecoration(
        tester,
        const ValueKey('match-betting-card'),
      ).boxShadow,
      isEmpty,
    );
    expect(
      decorationColor(tester, const ValueKey('match-tab-0')),
      app_style.AppPalette.white,
    );
    expect(
      decorationColor(tester, const ValueKey('match-tab-1')),
      app_style.AppPalette.lightGrey,
    );
    expect(
      decorationColor(tester, const ValueKey('match-preview-standing-header')),
      app_style.AppPalette.lightGrey,
    );
    expect(
      decorationColor(tester, const ValueKey('match-preview-standing-body')),
      app_style.AppPalette.darkGrey,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('match-preview-standing-club-header'),
            ),
          )
          .style!
          .color,
      app_style.AppPalette.white,
    );
    expect(
      tester.widget<Text>(find.text('MATCH PREVIEW')).style!.color,
      app_style.AppPalette.black,
    );
    expect(
      tester.widget<Text>(find.text('HEAD TO HEAD')).style!.color,
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('live match shell fits a compact viewport', (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
      matchId: '19200003',
      matchStatus: 'live',
    );

    expect(find.text('MATCH INFO'), findsOneWidget);
    expect(find.text('LIVE CHAT'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live chat keeps its selected tab visible and pinned',
      (tester) async {
    await pumpMatch(
      tester,
      theme: app_style.darktheme,
      size: const Size(320, 568),
      matchId: '19200003',
      matchStatus: 'live',
      chatRepository: _EmptyChatRepository(),
      chatSocket: _TestChatSocket(),
    );

    expect(find.text('ANALYSIS'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('LIVE CHAT'),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('match-tab-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('LIVE CHAT'));
    await tester.pumpAndSettle();

    final tab = tester.getRect(find.byKey(const ValueKey('match-tab-2')));
    final messageViewport = tester
        .getRect(find.byKey(const ValueKey('live-chat-message-viewport')));
    expect(tab.right, closeTo(320 - 24, 0.01));
    expect(messageViewport.top, greaterThanOrEqualTo(tab.bottom));
    expect(find.byKey(const ValueKey('live-chat-input')), findsOneWidget);
    expect(
      tester
          .widget<SliverPersistentHeader>(
            find.byType(SliverPersistentHeader),
          )
          .pinned,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

class _EmptyChatRepository implements ChatRepository {
  @override
  final ValueNotifier<Map<ChatRoom, List<FixtureChatMessage>>> cachedHistories =
      ValueNotifier(const {});

  @override
  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId,
          {required String language}) =>
      const [];

  @override
  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    required String language,
    int? beforeId,
    int? afterId,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<void> reportMessage({
    required int messageId,
    required String reason,
  }) async {}
}

class _TestChatSocket implements ChatSocket {
  @override
  Future<ChatSocketSession> connect(int fixtureId,
          {required String language}) async =>
      _TestChatSession();
}

class _TestChatSession implements ChatSocketSession {
  final StreamController<FixtureChatMessage> _messages =
      StreamController.broadcast();

  @override
  Stream<FixtureChatMessage> get messages => _messages.stream;

  @override
  Future<void> send(String text) async {}

  @override
  Future<void> close() => _messages.close();
}
