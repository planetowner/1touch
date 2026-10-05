import 'support/app_catalog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/round_chart_window.dart';
import 'package:onetouch/core/round_chart_visuals.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/screens/all_players_screen.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_contract_roster.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/anal.dart';
import 'support/player_detail_fixture.dart';

void main() {
  setUpAppCatalog();
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'match card preserves unknown counts and confirmed zero at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final json = playerDetailJson();
      json['matches'][0]['metrics'][0]['value'] = 0;
      json['matches'][0]['metrics'][1]['value'] = null;
      final match = playerDetailFromJson(json).matches.first;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: PlayerDetailMatchCard(match: match)),
      ));
      await tester.pumpAndSettle();
      final card = tester.widget<PlayerMatchCard>(find.byType(PlayerMatchCard));
      expect(card.stats[0].value, '0');
      expect(card.stats[1].value, '—');
      expect(tester.takeException(), isNull);
    });
  }
  final player = playerRepository.findById('lee-kang-in')!;
  for (final (role, theme, size) in [
    (TeamLeadershipRole.captain, app_style.darktheme, const Size(320, 568)),
    (
      TeamLeadershipRole.viceCaptain,
      app_style.whitetheme,
      const Size(430, 932)
    ),
    (null, app_style.darktheme, const Size(393, 852)),
  ]) {
    testWidgets('overview shows only the current leadership badge for $role',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _OverviewLeadershipRepository(role);

      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: PlayerCard(
          playerId: 1,
          detailRepository: FakePlayerDetailRepository(),
          contractRepository: repository,
        ),
      ));
      await tester.pumpAndSettle();

      expect(repository.requestedTeamId, 7980);
      expect(repository.requestedSeasonId, 27965);
      final badge = find.byKey(ValueKey(
        'player-overview-leadership-${role == TeamLeadershipRole.captain ? 'captain' : 'vice-captain'}',
      ));
      if (role == null) {
        expect(find.byKey(const ValueKey('player-overview-leadership-captain')),
            findsNothing);
        expect(
            find.byKey(
                const ValueKey('player-overview-leadership-vice-captain')),
            findsNothing);
      } else {
        expect(badge, findsOneWidget);
        expect(tester.getSize(badge), const Size(24, 18));
        expect(
            find.descendant(
                of: badge,
                matching:
                    find.text(role == TeamLeadershipRole.captain ? 'C' : 'VC')),
            findsOneWidget);
        final badgeRect = tester.getRect(badge);
        final imageRect = tester.getRect(
          find.byKey(const ValueKey('player-overview-image')),
        );
        expect(badgeRect.top, imageRect.top);
        expect(badgeRect.right, imageRect.right);
        final decoration =
            tester.widget<Container>(badge).decoration! as BoxDecoration;
        expect(
            decoration.border!.top.color,
            theme.brightness == Brightness.dark
                ? app_style.AppPalette.white
                : app_style.AppPalette.black);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('player gradient is limited to the app bar and tabs', () {
    expect(playerDetailHeaderGradientHeight(20), 168);
    expect(playerDetailHeaderGradientHeight(59), 207);
    expect(playerDetailOverviewGradientHeight(20), 364);
    expect(playerDetailOverviewGradientHeight(59), 403);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('player gradient smoothly shrinks and expands at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: MediaQuery(
          data: MediaQueryData(
              size: size, padding: const EdgeInsets.only(top: 59)),
          child: PlayerCard(
            player: player,
            detailRepository: FakePlayerDetailRepository(),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      const gradientKey = ValueKey('player-detail-overview-gradient');
      expect(
          tester.getSize(find.byKey(gradientKey)).height, closeTo(403, 0.01));

      await tester.tap(find.text('Analysis').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final shrinkingHeight = tester.getSize(find.byKey(gradientKey)).height;
      expect(shrinkingHeight, greaterThan(207));
      expect(shrinkingHeight, lessThan(403));

      await tester.pumpAndSettle();
      expect(find.byKey(gradientKey), findsNothing);

      tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      final expandingHeight = tester.getSize(find.byKey(gradientKey)).height;
      expect(expandingHeight, greaterThan(207));
      expect(expandingHeight, lessThan(403));

      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byKey(gradientKey)).height, closeTo(403, 0.01));

      final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      controller.offset = 0.5;
      await tester.pump();
      expect(tester.getSize(find.byKey(gradientKey)).height,
          closeTo((403 + 207) / 2, 1));
      controller.offset = 0;
      await tester.pump();

      controller.animateTo(3);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getSize(find.byKey(gradientKey)).height,
          inInclusiveRange(208, 402));
      await tester.pumpAndSettle();
      expect(find.byKey(gradientKey), findsNothing);

      controller.animateTo(0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getSize(find.byKey(gradientKey)).height,
          inInclusiveRange(208, 402));
      await tester.pumpAndSettle();
      expect(
          tester.getSize(find.byKey(gradientKey)).height, closeTo(403, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('player detail search opens the shared search page',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => PlayerCard(
            player: player,
            detailRepository: FakePlayerDetailRepository(),
          ),
        ),
        GoRoute(
          path: '/search',
          builder: (_, __) => const Scaffold(
            key: ValueKey('shared-search-page'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-search-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shared-search-page')), findsOneWidget);
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
            (label: 'Touches', value: '100'),
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
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('player-match-logo'))).dx -
          tester
              .getTopLeft(find.byKey(const ValueKey('player-match-card-top')))
              .dx,
      16,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('player-match-result'))).dx -
          tester
              .getTopRight(find.byKey(const ValueKey('player-match-logo')))
              .dx,
      8,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('player-match-score'))).dx -
          tester
              .getTopRight(find.byKey(const ValueKey('player-match-result')))
              .dx,
      16,
    );
    expect(
      tester
              .getTopRight(find.byKey(const ValueKey('player-match-card-top')))
              .dx -
          tester
              .getTopRight(
                  find.byKey(const ValueKey('player-match-competition')))
              .dx,
      16,
    );
    expect(
      tester
              .getTopLeft(
                  find.byKey(const ValueKey('player-match-stat-value-Touches')))
              .dx -
          tester.getTopRight(find.text('Touch')).dx,
      4,
    );
    expect(
      tester
              .getTopRight(
                  find.byKey(const ValueKey('player-match-card-bottom')))
              .dx -
          tester
              .getTopRight(find.byKey(const ValueKey('player-match-rating')))
              .dx,
      16,
    );
  });

  testWidgets('Korean player match stats stay on one line with compact gaps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.darktheme,
      home: const Scaffold(
        body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: PlayerMatchCard(
            result: 'WIN',
            score: '3 - 0',
            competition: 'LA LIGA · Round 4',
            stats: [
              (label: 'Goals', value: '1'),
              (label: 'Assists', value: '2'),
              (label: 'Shots', value: '4'),
            ],
            rating: '8.4',
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final bottom = tester.widget<Container>(
      find.byKey(const ValueKey('player-match-card-bottom')),
    );
    expect(
      bottom.padding,
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
    for (final label in ['골', '도움', '슈팅']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 1);
      expect(tester.getSize(find.text(label)).height, lessThan(30));
    }
    final goalPair = tester.getRect(
      find.byKey(const ValueKey('player-match-stat-pair-Goals')),
    );
    final assistPair = tester.getRect(
      find.byKey(const ValueKey('player-match-stat-pair-Assists')),
    );
    final shotPair = tester.getRect(
      find.byKey(const ValueKey('player-match-stat-pair-Shots')),
    );
    final ratingGap = tester.widget<SizedBox>(
      find.byKey(const ValueKey('player-match-rating-gap')),
    );
    final bottomRect = tester.getRect(
      find.byKey(const ValueKey('player-match-card-bottom')),
    );
    final ratingRect = tester.getRect(
      find.byKey(const ValueKey('player-match-rating')),
    );
    expect(goalPair.left - bottomRect.left, 16);
    expect(assistPair.left - goalPair.right, 8);
    expect(shotPair.left - assistPair.right, 8);
    expect(ratingGap.width, 8);
    expect(bottomRect.right - ratingRect.right, 16);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('long player match stat scrolls on one line at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: PlayerMatchCard(
              result: 'WIN',
              score: '3 - 0',
              competition: 'LA LIGA',
              stats: [
                (label: 'Expected goals from outside the box', value: '1'),
                (label: 'Assists', value: '2'),
                (label: 'Shots', value: '4'),
              ],
              rating: '8.4',
            ),
          ),
        ),
      ));

      final label = find.byKey(const ValueKey(
          'player-match-stat-label-Expected goals from outside the box'));
      final text = tester.widget<Text>(
        find.descendant(of: label, matching: find.byType(Text)),
      );
      final scrollable = tester.state<ScrollableState>(
        find.descendant(of: label, matching: find.byType(Scrollable)),
      );
      expect(text.maxLines, 1);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));
      expect(scrollable.position.pixels, greaterThan(0));
      await tester.pump(const Duration(seconds: 6));
      expect(scrollable.position.pixels,
          closeTo(scrollable.position.maxScrollExtent, 0.1));
      expect(tester.takeException(), isNull);
    });
  }

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

    expect(scroll.padding, const EdgeInsets.fromLTRB(24, 24, 24, 24));
    expect(position.top - jersey.bottom, 24);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-overview-image'))),
      const Size.square(160),
    );
    final imageFade = tester.widget<ShaderMask>(
      find.byKey(const ValueKey('player-overview-image-bottom-fade')),
    );
    expect(imageFade.blendMode, BlendMode.dstIn);
    expect(
      tester.getSize(
        find.byKey(const ValueKey('player-overview-image-bottom-fade')),
      ),
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
      find.byKey(const ValueKey('player-detail-overview-gradient')),
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

      final overviewGradientContainer = tester.widget<Container>(
        find.byKey(const ValueKey('player-detail-overview-gradient')),
      );
      final overviewGradient =
          (overviewGradientContainer.decoration as BoxDecoration).gradient!
              as LinearGradient;
      final tabBar = tester.widget<TabBar>(find.byType(TabBar));
      final indicator = tabBar.indicator! as UnderlineTabIndicator;
      expect(overviewGradient.colors, testCase.gradientColors);
      expect(tabBar.labelColor, testCase.foreground);
      expect(tabBar.unselectedLabelColor, testCase.foreground);
      expect(indicator.borderSide.color, testCase.foreground);
      expect(
        tester
            .getSize(
                find.byKey(const ValueKey('player-detail-overview-gradient')))
            .height,
        closeTo(403, 0.01),
      );

      await tester.tap(find.text('Analysis').first);
      await tester.pumpAndSettle();
      final topStatsSurface = tester.widget<PlayerSurface>(
        find.byKey(const ValueKey('player-top-stats-card')),
      );
      final topStatValue = tester.widget<Container>(
        find.byKey(const ValueKey('player-top-stat-value-Key passes')),
      );
      final topStatDecoration = topStatValue.decoration! as BoxDecoration;
      expect(
        topStatsSurface.color,
        testCase.name == 'dark'
            ? app_style.AppPalette.lightGrey
            : app_style.AppPalette.lightGreyBox,
      );
      expect(
        topStatDecoration.color,
        testCase.name == 'dark'
            ? app_style.AppPalette.darkGrey
            : app_style.AppPalette.white,
      );
      expect(
        find.byKey(const ValueKey('player-detail-overview-gradient')),
        findsNothing,
      );
      final appBarGradientContainer = tester.widget<Container>(
        find.byKey(const ValueKey('player-detail-gradient')),
      );
      final tabGradientContainer = tester.widget<Container>(
        find.byKey(const ValueKey('player-detail-tab-gradient')),
      );
      final appBarGradient =
          (appBarGradientContainer.decoration as BoxDecoration).gradient!
              as LinearGradient;
      final tabGradient = (tabGradientContainer.decoration as BoxDecoration)
          .gradient! as LinearGradient;
      expect(appBarGradient.colors.first, testCase.gradientColors.last);
      expect(tabGradient.colors.last, testCase.gradientColors.first);
      expect(appBarGradient.colors.last, tabGradient.colors.first);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('player-detail-gradient')))
            .height,
        closeTo(159, 0.01),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('player-detail-tab-gradient')))
            .height,
        closeTo(48, 0.01),
      );
      expect(
        tester
            .getBottomLeft(find.byKey(const ValueKey('player-detail-gradient')))
            .dy,
        tester
            .getTopLeft(
                find.byKey(const ValueKey('player-detail-tab-gradient')))
            .dy,
      );
      await tester.drag(
        find.byKey(const ValueKey('player-analysis-scroll')),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-detail-gradient')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('player-detail-tab-gradient')),
        findsNothing,
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
            final trophiesCard = tester.widget<PlayerSurface>(
              find.byKey(const ValueKey('player-career-trophies-card')),
            );
            final historyCard = tester.widget<PlayerSurface>(
              find.byKey(const ValueKey('player-career-history-card')),
            );
            final teamHeader = tester.widget<Text>(
              find.byKey(const ValueKey('player-career-team-header')),
            );
            final expectedCareerCardColor = dark
                ? app_style.AppPalette.lightGrey
                : app_style.AppPalette.lightGreyBox;
            expect(
              trophiesCard.color,
              expectedCareerCardColor,
            );
            expect(historyCard.color, expectedCareerCardColor);
            expect(
              teamHeader.style?.color,
              dark ? app_style.AppPalette.white : app_style.AppPalette.black,
            );
            expect(find.text('UCL'), findsNothing);
            expect(find.text('Champions League'), findsOneWidget);
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
    final overviewMatchBoxes = find.byKey(const ValueKey('player-match-card'));
    expect(overviewCards.length, 3);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-matches-arrow'))),
      const Size.square(24),
    );
    expect(
      tester.getTopLeft(overviewMatchBoxes.at(1)).dy -
          tester.getBottomLeft(overviewMatchBoxes.at(0)).dy,
      16,
    );
    final clubHistoryCard = tester.widget<PlayerSurface>(
      find.byKey(const ValueKey('player-club-history-card')),
    );
    final firstClubRow =
        find.byKey(const ValueKey('player-club-history-row-7980'));
    final secondClubRow =
        find.byKey(const ValueKey('player-club-history-row-591'));
    final firstClubName = tester.widget<Text>(
      find.byKey(const ValueKey('player-club-history-name-7980')),
    );
    expect(clubHistoryCard.padding, const EdgeInsets.all(16));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('player-club-history-logo-7980'))),
      const Size.square(24),
    );
    expect(firstClubName.style, Heading5.style);
    expect(
      tester.getTopLeft(secondClubRow).dy -
          tester.getBottomLeft(firstClubRow).dy,
      16,
    );
    expect(overviewCards.first.match.metrics.map((m) => m.code),
        ['goals', 'assists', 'shots']);
    await tester.tap(find.text('Matches').first);
    await tester.pumpAndSettle();
    final matchesSelector = tester.widget<PlayerSeasonSelector>(
      find.byType(PlayerSeasonSelector),
    );
    final matchesSelectorRect = tester.getRect(
      find.byKey(ValueKey(
          'player-matches-season-${matchesSelector.detail.selectedSeason?.id}')),
    );
    expect(matchesSelector.width, double.infinity);
    expect(matchesSelectorRect.left, 24);
    expect(
      matchesSelectorRect.right,
      tester.getSize(find.byType(MaterialApp)).width - 24,
    );
    expect(
      tester.getTopLeft(find.text('RECENT MATCHES')).dy -
          matchesSelectorRect.bottom,
      32,
    );
    final matches = tester
        .widgetList<PlayerDetailMatchCard>(find.byType(PlayerDetailMatchCard))
        .toList();
    expect(matches.length, 8);
    expect(matches.first.match.metrics.map((m) => m.code),
        ['goals', 'assists', 'shots']);
    expect(find.text('LIVE'), findsNothing);
    expect(repository.calls.length, 1);
  });
  testWidgets('top stats help stays directly beside its section title',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('competition-stats-help-icon')),
        findsNothing);
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('top-stats-help-icon'))).dx -
          tester.getTopRight(find.text('TOP STATS')).dx,
      4,
    );
    expect(tester.getSize(find.byKey(const ValueKey('top-stats-help-icon'))),
        const Size(20, 20));
    await tester.tap(find.byKey(const ValueKey('top-stats-help-icon')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsOneWidget);
    expect(
      find.text(
          'Top 3 stats where the player ranks best in the league. The displayed stats will only reflect good performance.'),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('app-info-popup')), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('competition stats show the card without help or footer note',
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
    final ratingFinder =
        find.byKey(const ValueKey('player-competition-rating-2'));
    final ratingBox = tester.widget<Container>(ratingFinder);
    final ratingDecoration = ratingBox.decoration! as BoxDecoration;
    final ratingText = tester.widget<Text>(
      find.descendant(of: ratingFinder, matching: find.byType(Text)),
    );

    expect(card, findsOneWidget);
    expect(find.byKey(const ValueKey('competition-stats-help-icon')),
        findsNothing);
    expect(find.byKey(const ValueKey('player-competition-collected-note')),
        findsNothing);
    expect(find.text('UCL'), findsOneWidget);
    expect(find.text('Champions League'), findsNothing);
    expect(find.text('LA LIGA'), findsOneWidget);
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

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final locale in [const Locale('en'), const Locale('ko')]) {
      testWidgets(
          'competition stat headers align with values at $size in $locale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        appLocaleController.value = locale;
        addTearDown(() => appLocaleController.value = const Locale('en'));

        await tester.pumpWidget(MaterialApp(
          theme: app_style.darktheme,
          home: PlayerCard(
            player: player,
            detailRepository: FakePlayerDetailRepository(),
          ),
        ));
        await tester.pumpAndSettle();

        final headerTexts = find.descendant(
          of: find.byKey(const ValueKey('player-competition-header-surface')),
          matching: find.byType(Text),
        );
        final valueTexts = find.descendant(
          of: find.byKey(const ValueKey('player-competition-row-2')),
          matching: find.byType(Text),
        );
        expect(headerTexts, findsNWidgets(4));
        expect(valueTexts, findsNWidgets(4));
        for (var column = 1; column < 4; column++) {
          final headerX = tester.getCenter(headerTexts.at(column)).dx;
          final valueX = tester.getCenter(valueTexts.at(column)).dx;
          expect(headerX, closeTo(valueX, 0.1));
        }
        for (final name in ['mp', 'wr', 'rating']) {
          final header = tester.getRect(
            find.byKey(ValueKey('player-competition-header-$name')),
          );
          final value = tester.getRect(
            find.byKey(ValueKey('player-competition-row-2-$name')),
          );
          expect(header.center.dx, closeTo(value.center.dx, 0.1));
        }
        final mp = tester.getRect(
          find.byKey(const ValueKey('player-competition-header-mp')),
        );
        final wr = tester.getRect(
          find.byKey(const ValueKey('player-competition-header-wr')),
        );
        final rating = tester.getRect(
          find.byKey(const ValueKey('player-competition-header-rating')),
        );
        expect(wr.left - mp.right, closeTo(rating.left - wr.right, 0.1));
        final card = tester.getRect(
          find.byKey(const ValueKey('player-competition-stats-card')),
        );
        final row = tester.getRect(
          find.byKey(const ValueKey('player-competition-row-2')),
        );
        final ratingColumn = tester.getRect(
          find.byKey(const ValueKey('player-competition-row-2-rating')),
        );
        final ratingBox = tester.getRect(
          find.byKey(const ValueKey('player-competition-rating-2')),
        );
        expect(card.right - row.right, closeTo(16, 0.1));
        expect(card.right - ratingColumn.right, closeTo(16, 0.1));
        expect(ratingBox.width, lessThan(ratingColumn.width));
        expect(ratingBox.center.dx, closeTo(ratingColumn.center.dx, 0.1));
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final size in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(430, 932),
  ]) {
    for (final locale in [const Locale('en'), const Locale('ko')]) {
      testWidgets('influence cards fit $size in ${locale.languageCode}',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        appLocaleController.value = locale;
        addTearDown(() => appLocaleController.value = const Locale('en'));
        final detail = detailFixture();
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: locale.languageCode == 'en'
              ? app_style.darktheme
              : app_style.whitetheme,
          home: Scaffold(
            body: PlayerDetailScope(
              store: PlayerDetailStore(
                playerId: detail.playerId,
                initial: detail,
              ),
              child: AnalysisTab(playerId: detail.playerId),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final cards = find.descendant(
          of: find.byType(GridView),
          matching: find.byType(PlayerSurface),
        );
        expect(cards, findsNWidgets(2));
        for (final card in cards.evaluate()) {
          final finder = find.byElementPredicate((element) => element == card);
          final surface = tester.widget<PlayerSurface>(finder);
          final rect = tester.getRect(finder);
          final textFinders = find.descendant(
            of: finder,
            matching: find.byType(Text),
          );
          final texts = tester.widgetList<Text>(textFinders).toList();
          expect(rect.width, closeTo((size.width - 64) / 2, 0.1));
          expect(rect.height, closeTo(rect.width, 0.1));
          expect(surface.padding, const EdgeInsets.all(16));
          expect(surface.radius, 24);
          expect(
              surface.color,
              locale.languageCode == 'en'
                  ? const Color(0xFF272828)
                  : Colors.white);
          expect(texts.first.style?.fontSize, 15);
          expect(texts.first.style?.height, 1.3);
          expect(texts[1].style?.fontSize, 48);
          expect(texts[1].style?.height, 0.9);
          expect(texts.last.style?.fontSize, 20);
          expect(texts.last.style?.height, 1.2);
          expect(tester.getRect(textFinders.at(0)).top - rect.top,
              closeTo(16, 0.1));
          expect(rect.bottom - tester.getRect(textFinders.at(1)).bottom,
              closeTo(16, 0.1));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('season selection loads its own data', (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
        home: PlayerCard(player: player, detailRepository: repository)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.text('Starting Rate'), findsOneWidget);
    expect(find.text('Win Rate'), findsOneWidget);
    expect(find.text('Minutes Played\nPer Game'), findsNothing);
    expect(find.text('Goal\nContributions'), findsNothing);
    expect(find.text('Key Passes'), findsOneWidget);
    expect(find.text('Ball Recoveries'), findsOneWidget);
    expect(find.text('Passes in Final Third'), findsOneWidget);
    expect(find.text('Key passes'), findsNothing);
    expect(find.text('Ball recoveries'), findsNothing);
    expect(find.text('Passes in final third'), findsNothing);
    final topStatsSurface = tester.widget<PlayerSurface>(
      find.byKey(const ValueKey('player-top-stats-card')),
    );
    final topStatValue = tester.widget<Container>(
      find.byKey(const ValueKey('player-top-stat-value-Key passes')),
    );
    final topStatDecoration = topStatValue.decoration! as BoxDecoration;
    final topStatLabel = tester.widget<Center>(
      find.byKey(const ValueKey('player-top-stat-label-Key passes')),
    );
    final topStatRank = tester.widget<Text>(find.descendant(
      of: find.byKey(const ValueKey('player-top-stat-rank-Key passes')),
      matching: find.byType(Text),
    ));
    expect(topStatsSurface.color, app_style.AppPalette.lightGreyBox);
    expect(topStatsSurface.padding, const EdgeInsets.all(24));
    expect(topStatDecoration.color, app_style.AppPalette.white);
    expect(topStatLabel.heightFactor, isNull);
    expect(topStatRank.data, '#1');
    final selector =
        tester.widget<PlayerSeasonSelector>(find.byType(PlayerSeasonSelector));
    final selectorRect = tester.getRect(
      find.byKey(ValueKey(
          'player-analysis-season-${selector.detail.selectedSeason?.id}')),
    );
    expect(selector.width, double.infinity);
    expect(selectorRect.left, 24);
    expect(selectorRect.right,
        tester.getSize(find.byType(MaterialApp)).width - 24);
    selector.onChanged(selector.detail.seasons.last.id);
    await tester.pumpAndSettle();
    expect(repository.calls.last.seasonId, selector.detail.seasons.last.id);
    expect(find.text('ATTRIBUTES'), findsOneWidget);
    expect(find.text('Coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean top stat names stay on one line when they fit',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final previousLocale = appLocaleController.value;
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = previousLocale);

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: app_style.darktheme,
      home: PlayerCard(
        player: player,
        detailRepository: FakePlayerDetailRepository(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('분석').first);
    await tester.pumpAndSettle();

    final surface = tester.widget<PlayerSurface>(
      find.byKey(const ValueKey('player-top-stats-card')),
    );
    expect(
      surface.padding,
      const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
    );
    for (final label in ['키 패스', '볼 회수', '공격 지역 패스']) {
      final text = tester.widget<Text>(find.text(label));
      expect(text.maxLines, 2);
      expect(tester.getSize(find.text(label)).height, lessThan(30));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('performance chart follows the team current form format',
      (tester) async {
    final repository = FakePlayerDetailRepository();
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: PlayerCard(player: player, detailRepository: repository),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analysis').first);
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('player-performance-card'));
    final chart = find.byKey(const ValueKey('player-performance-chart'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();

    final lineChart = tester.widget<LineChart>(
      find.descendant(of: chart, matching: find.byType(LineChart)),
    );
    final axisLabel = tester.widget<RotatedBox>(
      find.byKey(const ValueKey('player-performance-axis-label')),
    );
    expect(tester.getSize(card).height, 346);
    expect(lineChart.data.minX, -2);
    expect(lineChart.data.maxX, 10);
    expect(lineChart.data.minY, 6);
    expect(lineChart.data.maxY, 9.5);
    expect(lineChart.data.lineBarsData.single.dotData.show, isFalse);
    expect(
      find.byKey(const ValueKey('player-performance-grid')),
      findsOneWidget,
    );
    final gridPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('player-performance-grid')),
        )
        .painter! as RoundChartGridPainter;
    expect(gridPainter.divisionCount + 1, 12);
    expect(
      tester
              .getTopLeft(
                  find.byKey(const ValueKey('player-performance-round-label')))
              .dy -
          tester
              .getBottomLeft(
                  find.byKey(const ValueKey('player-performance-grid')))
              .dy,
      12 + RoundChartSelectionHandle.height,
    );
    expect(axisLabel.quarterTurns, 1);

    final chartRect = tester.getRect(
      find.byKey(const ValueKey('player-performance-viewport')),
    );
    expect(
      find.byKey(const ValueKey('player-performance-tooltip')),
      findsOneWidget,
    );
    final performanceHandle = find.descendant(
      of: find.byKey(const ValueKey('player-performance-viewport')),
      matching: find.byKey(const ValueKey('round-chart-selection-handle')),
    );
    expect(
        tester.getRect(performanceHandle).left +
            RoundChartSelectionHandle.tipInset,
        closeTo(chartRect.center.dx, 0.1));
    expect(
      tester.getRect(performanceHandle).top,
      tester
          .getRect(find.byKey(const ValueKey('player-performance-grid')))
          .bottom,
    );
    expect(find.text('Round 7'), findsOneWidget);
    expect(find.text('Rating 6.94'), findsOneWidget);
    await tester.tapAt(chartRect.center);
    await tester.pump();
    expect(find.text('Round 7'), findsOneWidget);
    final drag = await tester.startGesture(tester.getCenter(performanceHandle));
    await drag.moveBy(Offset(-chartRect.width / 6, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('Round 6'), findsOneWidget);
    final dynamic selectionPainter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey('player-performance-selector-line')),
        )
        .painter;
    expect(selectionPainter.round, 6);
    final tooltipRect = tester.getRect(
      find.byKey(const ValueKey('player-performance-tooltip')),
    );
    expect(tooltipRect.left, greaterThanOrEqualTo(chartRect.left));
    expect(tooltipRect.right, lessThanOrEqualTo(chartRect.right));
    expect(
        tester.getRect(performanceHandle).left +
            RoundChartSelectionHandle.tipInset,
        closeTo(chartRect.center.dx, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('performance can select earlier rounds by its handle',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerPerformanceChart(
          points: [
            for (var round = 1; round <= 20; round++)
              (fixtureId: round, round: round, rating: 6.0),
          ],
        ),
      ),
    ));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect((chart.data.minX, chart.data.maxX), (-2, 23));
    expect(chart.data.lineBarsData.single.spots.length, 20);
    final viewport = find.byKey(const ValueKey('player-performance-viewport'));
    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
          of: viewport, matching: find.byType(SingleChildScrollView)),
    );
    expect(scroll.controller!.offset,
        closeTo(tester.getSize(viewport).width * 16 / 6, 0.1));
    expect(find.text('Round 17'), findsOneWidget);
    final handle = find.descendant(
      of: viewport,
      matching: find.byKey(const ValueKey('round-chart-selection-handle')),
    );
    final drag = await tester.startGesture(tester.getCenter(handle));
    await drag.moveBy(Offset(-tester.getSize(viewport).width / 6, 0));
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('Round 16'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('performance shows all four completed rounds before round eight',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PlayerPerformanceChart(
          points: [
            for (var round = 1; round <= 4; round++)
              (fixtureId: round, round: round, rating: 6.0 + round / 10),
          ],
        ),
      ),
    ));

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect((chart.data.minX, chart.data.maxX), (-2, 10));
    expect(chart.data.lineBarsData.single.spots.map((spot) => spot.x),
        [1, 2, 3, 4]);
    final viewport = find.byKey(const ValueKey('player-performance-viewport'));
    final scroll = tester.widget<SingleChildScrollView>(
      find.descendant(
        of: viewport,
        matching: find.byType(SingleChildScrollView),
      ),
    );
    expect(scroll.controller!.offset,
        closeTo(tester.getSize(viewport).width / 2, 0.1));
    expect(find.text('Round 4'), findsOneWidget);
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

  testWidgets('club history keeps repeated team periods as unique rows',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerCard(
          player: player,
          detailRepository: FakePlayerDetailRepository(
            duplicateFirstClub: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('player-club-history-row-7980')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('player-club-history-row-7980-4')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supported club history teams open their Team page',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => PlayerCard(
            player: player,
            detailRepository: FakePlayerDetailRepository(),
          ),
        ),
        GoRoute(
          path: '/team/:teamId',
          builder: (_, state) => Scaffold(
            body: Text('team-${state.pathParameters['teamId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    final club = find.byKey(
      const ValueKey('player-club-history-row-7980'),
    );
    await tester.ensureVisible(club);
    await tester.tap(club);
    await tester.pumpAndSettle();

    expect(find.text('team-7980'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _OverviewLeadershipRepository implements TeamContractRepository {
  _OverviewLeadershipRepository(this.role);

  final TeamLeadershipRole? role;
  int? requestedTeamId;
  int? requestedSeasonId;
  final ValueNotifier<Map<TeamContractQuery, TeamContractRoster>> _cache =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<TeamContractQuery, TeamContractRoster>>
      get cachedRosters => _cache;

  @override
  TeamContractRoster? cachedForTeam(int teamId, {int? seasonId}) => null;

  @override
  Future<TeamContractRoster> loadForTeam(int teamId, {int? seasonId}) async {
    requestedTeamId = teamId;
    requestedSeasonId = seasonId;
    return TeamContractRoster(
      teamId: teamId,
      seasonId: 27965,
      isCurrent: true,
      players: [
        TeamPlayerContract(
          playerId: 1,
          playerName: 'Player 1',
          leadershipRole: role,
        ),
      ],
    );
  }
}
