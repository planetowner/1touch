import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
  final player = playerRepository.findById('lee-kang-in')!;
  test('player gradient ends below the overview profile', () {
    expect(playerDetailOverviewGradientHeight(20), 364);
    expect(playerDetailOverviewGradientHeight(59), 403);
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

  testWidgets('overview jersey number removes top leading beside player image',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final jersey = tester.widget<Text>(
      find.byKey(const ValueKey('player-overview-jersey-number')),
    );
    final jerseyTop = tester.getTopLeft(
      find.byKey(const ValueKey('player-overview-jersey-number')),
    );
    final imageTop = tester.getTopLeft(
      find.byKey(const ValueKey('player-overview-image')),
    );

    expect(jersey.textHeightBehavior?.applyHeightToFirstAscent, isFalse);
    expect(jerseyTop.dy, imageTop.dy);
  });

  testWidgets('overview uses the reference profile dimensions and spacing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final scroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('player-overview-scroll')),
    );
    final jersey = tester.getRect(
      find.byKey(const ValueKey('player-overview-jersey-number')),
    );
    final position = tester.getRect(
      find.byKey(const ValueKey('player-overview-position')),
    );

    expect(scroll.padding, const EdgeInsets.fromLTRB(24, 24, 24, 144));
    expect(position.top - jersey.bottom, 24);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-overview-image'))),
      const Size.square(160),
    );
  });

  testWidgets('overview position team and country use 8px vertical spacing',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final position = tester.getRect(
      find.byKey(const ValueKey('player-overview-position')),
    );
    final team = tester.getRect(
      find.byKey(const ValueKey('player-overview-team-name')),
    );
    final country = tester.getRect(
      find.byKey(const ValueKey('player-overview-country')),
    );

    expect(team.top - position.bottom, 8);
    expect(country.top - team.bottom, 8);
  });

  testWidgets('overview country has 16px of bottom padding', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final topBlock = tester.getRect(
      find.byKey(const ValueKey('player-overview-top-block')),
    );
    final country = tester.getRect(
      find.byKey(const ValueKey('player-overview-country')),
    );

    expect(topBlock.bottom - country.bottom, 16);
  });

  testWidgets('Korean profile metrics expand without vertical overflow',
      (tester) async {
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = const Locale('en'));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final topBlock = tester.getRect(
      find.byKey(const ValueKey('player-overview-top-block')),
    );
    final country = tester.getRect(
      find.byKey(const ValueKey('player-overview-country')),
    );
    final gradient = tester.getRect(
      find.byKey(const ValueKey('player-detail-gradient')),
    );

    expect(topBlock.height, greaterThanOrEqualTo(160));
    expect(topBlock.bottom - country.bottom, 16);
    expect(gradient.bottom, greaterThanOrEqualTo(topBlock.bottom));
    expect(tester.takeException(), isNull);
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
        closeTo(403, 0.01),
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
  testWidgets('competition stats keep the collected-since note below the card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('player-competition-stats-card'));
    final note =
        find.byKey(const ValueKey('player-competition-collected-note'));
    final opacity = tester.widget<Opacity>(note);
    final noteText = tester.widget<Text>(
      find.descendant(of: note, matching: find.byType(Text)),
    );
    final ratingFinder =
        find.byKey(const ValueKey('player-competition-rating-2'));
    final ratingBox = tester.widget<Container>(ratingFinder);
    final ratingDecoration = ratingBox.decoration! as BoxDecoration;
    final ratingText = tester.widget<Text>(
      find.descendant(of: ratingFinder, matching: find.byType(Text)),
    );

    expect(tester.getTopLeft(note).dy - tester.getBottomLeft(card).dy, 12);
    expect(opacity.opacity, 0.5);
    expect(noteText.style?.fontSize, 14);
    expect(noteText.style?.fontWeight, FontWeight.w400);
    expect(noteText.style?.height, 1.3);
    expect(find.text('UCL'), findsOneWidget);
    expect(find.text('Champions League'), findsNothing);
    expect(find.text('La Liga'), findsOneWidget);
    expect(tester.getSize(ratingFinder).height, 32);
    expect(ratingBox.padding, const EdgeInsets.all(8));
    expect(ratingDecoration.color, app_style.AppPalette.black);
    expect(ratingDecoration.borderRadius, BorderRadius.circular(4));
    expect(ratingText.style?.fontSize, 15);
    expect(ratingText.style?.fontWeight, FontWeight.w700);
    expect(ratingText.style?.height, 1.3);
    expect(ratingText.style?.color, app_style.AppPalette.white);
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
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Minutes Played\nPer Game'), findsOneWidget);
    expect(find.text('Goal\nContributions'), findsOneWidget);
    final selector =
        tester.widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector));
    selector.onChanged(selector.detail.seasons.last.id);
    await tester.pumpAndSettle();
    expect(repository.calls.last.seasonId, selector.detail.seasons.last.id);
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
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
