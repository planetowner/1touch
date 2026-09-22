import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';
import 'support/player_detail_fixture.dart';

void main() {
  final player = playerRepository.findById('lee-kang-in')!;
  test('player gradient ends below the overview profile', () {
    expect(playerDetailOverviewGradientHeight(20), 329);
    expect(playerDetailOverviewGradientHeight(59), 368);
    expect(playerDetailTabGradientHeight(20), 168);
    expect(playerDetailTabGradientHeight(59), 207);
  });

  testWidgets('match crests render without a background tile', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: const Scaffold(
        body: PlayerMatchCard(
          result: 'WIN',
          score: '1 - 0',
          competition: 'Bundesliga',
          stats: [
            {'label': 'Touches', 'value': '100'},
          ],
          rating: '8.0',
        ),
      ),
    ));
    final backing = tester.widget<SizedBox>(
      find.byKey(const ValueKey('player-match-logo')),
    );
    expect(backing.width, 32);
    expect(backing.height, 32);
  });

  for (final testCase in <({
    String name,
    ThemeData theme,
    Color foreground,
    List<Color> gradientColors,
  })>[
    (
      name: 'light',
      theme: app_style.whitetheme,
      foreground: app_style.AppPalette.black,
      gradientColors: const [Color(0x333D3D3D), Color(0x003D3D3D)],
    ),
    (
      name: 'dark',
      theme: app_style.darktheme,
      foreground: app_style.AppPalette.white,
      gradientColors: const [Color(0xFF282929), Color(0x00282929)],
    ),
  ]) {
    testWidgets('player detail uses the ${testCase.name} neutral gradient',
        (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakePlayerDetailRepository();

      await tester.pumpWidget(MaterialApp(
        theme: testCase.theme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(393, 852),
            padding: EdgeInsets.only(top: 59),
          ),
          child: PlayerCard(player: player, detailRepository: repository),
        ),
      ));
      await tester.pumpAndSettle();

      final gradientContainer = tester.widget<Container>(
        find.byKey(const ValueKey('player-detail-gradient')),
      );
      final gradient = (gradientContainer.decoration as BoxDecoration).gradient!
          as LinearGradient;
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final indicator = tabBar.indicator! as UnderlineTabIndicator;
      expect(gradient.colors, testCase.gradientColors);
      expect(tabBar.labelColor, testCase.foreground);
      expect(tabBar.unselectedLabelColor, testCase.foreground);
      expect(indicator.borderSide.color, testCase.foreground);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('player-detail-gradient')))
            .height,
        closeTo(368, 0.01),
      );

      await tester.tap(find.text('Analysis').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('player-detail-gradient')))
            .height,
        closeTo(207, 0.01),
      );
      expect(tester.takeException(), isNull);
    });
  }
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
  testWidgets('help icons stay directly beside their section titles',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();

    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey('competition-stats-help-icon')),
              )
              .dx -
          tester.getTopRight(find.text('COMPETITION STATS')).dx,
      4,
    );

    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-stats-help-icon'))).dx -
          tester.getTopRight(find.text('TOP STATS')).dx,
      4,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('season selection loads its own data', (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('아직 준비중이에요 ㅠㅠ'), findsOneWidget);
    expect(find.text('Minutes Played\nPer Game'), findsOneWidget);
    expect(find.text('Goal\nContributions'), findsOneWidget);
    final selector =
        tester.widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector));
    selector.onChanged(selector.detail.seasons.last.id);
    await tester.pumpAndSettle();
    expect(repository.calls.last.seasonId, selector.detail.seasons.last.id);
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('아직 준비중이에요 ㅠㅠ'), findsOneWidget);
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
