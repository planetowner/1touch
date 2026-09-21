import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'support/player_detail_fixture.dart';

void main() {
  final player = playerRepository.findById('lee-kang-in')!;
  test('player gradient ends below the overview profile', () {
    expect(playerDetailOverviewGradientHeight(20), 329);
    expect(playerDetailOverviewGradientHeight(59), 368);
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets('all real player tabs fit $size dark=$dark', (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = FakePlayerDetailRepository();
        for (final tab in ['Overview', 'Analysis', 'Matches', 'Career']) {
          await tester.pumpWidget(MaterialApp(
              theme: dark ? app_style.darktheme : app_style.whitetheme,
              home: PlayerCard(
                  key: ValueKey(tab),
                  player: player,
                  detailRepository: repository)));
          await tester.pumpAndSettle();
          if (tab != 'Overview') {
            await tester.ensureVisible(find.text(tab).first);
            await tester.tap(find.text(tab).first);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: tab);
          final scroll =
              find.byKey(ValueKey('player-${tab.toLowerCase()}-scroll'));
          expect(scroll, findsOneWidget);
          await tester.drag(scroll, const Offset(0, -500));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '$tab after scrolling');
          if (tab == 'Career') {
            expect(find.text('PERSONAL'), findsNothing);
            expect(
                find.text('Team trophy records unavailable'), findsOneWidget);
          }
        }
      });
    }
  }
  testWidgets(
      'overview and matches use the same API metrics and one initial request',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();
    final overviewCards = tester
        .widgetList<PlayerDetailMatchCard>(find.byType(PlayerDetailMatchCard))
        .toList();
    expect(overviewCards.length, 3);
    expect(overviewCards.first.match.metrics.map((m) => m.code),
        ['goals', 'assists', 'shots']);
    await tester.tap(find.text('Matches').first);
    await tester.pumpAndSettle();
    final matches = tester
        .widgetList<PlayerDetailMatchCard>(find.byType(PlayerDetailMatchCard))
        .toList();
    expect(matches.length, 8);
    expect(matches.first.match.metrics.map((m) => m.code),
        ['goals', 'assists', 'shots']);
    expect(find.text('LIVE'), findsNothing);
    expect(repository.calls.length, 1);
  });
  testWidgets('season selection loads its own data', (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    final selector =
        tester.widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector));
    selector.onChanged(selector.detail.seasons.last.id);
    await tester.pumpAndSettle();
    expect(repository.calls.last.seasonId, selector.detail.seasons.last.id);
    expect(find.text('Minutes Played'), findsNothing);
    expect(find.text('Goal Contributions'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed detail has retry without mock competitions',
      (tester) async {
    final repository = FakePlayerDetailRepository()..fail = true;
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();
    expect(find.text('Could not load player data'), findsOneWidget);
    expect(find.byType(PlayerCompetitionTable), findsNothing);
    repository.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerCompetitionTable), findsOneWidget);
  });
}
