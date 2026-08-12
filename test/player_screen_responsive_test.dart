import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/screens/AllPlayersScreen.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/Overview.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(430, 932),
  ];
  final salah = playerRepository.findById('mohamed-salah')!;

  for (final size in phoneSizes) {
    testWidgets('player screen fits a ${size.width}x${size.height} viewport',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final horizontalPadding = (size.width * 0.05).clamp(16.0, 24.0);
      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(
                  height: 100,
                  child: PlayerScreenHeader(
                    player: salah,
                    horizontalPadding: horizontalPadding,
                    foregroundColor: app_style.AppPalette.white,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: PlayerBioStatsBlock(player: salah),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Mohamed Salah'), findsOneWidget);
      expect(find.text('Cost-Effectiveness'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('player detail uses light surfaces and anchored scrolling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: PlayerCard(player: salah),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final tabIndicator = tabBar.indicator! as UnderlineTabIndicator;
    final nestedScroll =
        tester.widget<NestedScrollView>(find.byType(NestedScrollView));
    final overviewScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('player-overview-scroll')),
    );
    final bioCard = tester.widget<Container>(
      find.byKey(const ValueKey('player-bio-stats-card')),
    );
    final followIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('player-follow-button')),
        matching: find.byType(Icon),
      ),
    );
    final searchIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('player-search-button')),
        matching: find.byType(Icon),
      ),
    );
    final compareIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const ValueKey('player-compare-button')),
        matching: find.byType(Icon),
      ),
    );

    expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
    expect(tabBar.labelColor, app_style.AppPalette.black);
    expect(tabIndicator.borderSide.color, app_style.AppPalette.black);
    expect(followIcon.color, app_style.AppPalette.black);
    expect(searchIcon.color, app_style.AppPalette.black);
    expect(compareIcon.color, app_style.AppPalette.black);
    expect(
      (bioCard.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    expect(nestedScroll.physics, isA<ClampingScrollPhysics>());
    expect(overviewScroll.physics, isA<ClampingScrollPhysics>());

    final topBlock = find.byKey(const ValueKey('player-overview-top-block'));
    final topBeforeDrag = tester.getTopLeft(topBlock).dy;
    await tester.drag(
      find.byKey(const ValueKey('player-overview-scroll')),
      const Offset(0, 300),
    );
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(topBlock).dy, closeTo(topBeforeDrag, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('all player detail tabs use light cards', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: PlayerCard(player: salah),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Analysis'));
    await tester.pumpAndSettle();
    final analysisCard = tester.widget<Container>(
      find.byKey(const ValueKey('player-top-stats-card')),
    );
    expect(
      (analysisCard.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull,
        reason: 'Analysis must not overflow');

    await tester.tap(find.text('Matches'));
    await tester.pumpAndSettle();
    final matchFilter = tester.widget<Container>(
      find.byKey(const ValueKey('player-matches-season-filter')),
    );
    expect(
      (matchFilter.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull, reason: 'Matches must not overflow');

    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();
    final careerCard = tester.widget<Container>(
      find.byKey(const ValueKey('player-career-trophies-card')),
    );
    expect(
      (careerCard.decoration as BoxDecoration).color,
      app_style.AppPalette.white,
    );
    expect(tester.takeException(), isNull, reason: 'Career must not overflow');
  });

  for (final testCase in <({
    String name,
    ThemeData theme,
    Color foreground,
  })>[
    (
      name: 'light',
      theme: app_style.whitetheme,
      foreground: app_style.AppPalette.black,
    ),
    (
      name: 'dark',
      theme: app_style.darktheme,
      foreground: app_style.AppPalette.white,
    ),
  ]) {
    testWidgets('player filters use ${testCase.name} foreground colors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: PlayerCard(player: salah),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Analysis'));
      await tester.pumpAndSettle();
      final analysisFilter = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('player-analysis-season-filter')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(analysisFilter.style?.color, testCase.foreground);
      for (final item in analysisFilter.items!) {
        final text = item.child as Text;
        expect(text.style?.color, testCase.foreground);
        expect(text.data, text.data!.toUpperCase());
      }

      await tester.tap(find.text('Matches'));
      await tester.pumpAndSettle();
      final matchFilter = tester.widget<DropdownButton<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('player-matches-season-filter')),
          matching: find.byType(DropdownButton<String>),
        ),
      );
      expect(matchFilter.style?.color, testCase.foreground);
      for (final item in matchFilter.items!) {
        final text = item.child as Text;
        expect(text.style?.color, testCase.foreground);
        expect(text.data, text.data!.toUpperCase());
      }

      await tester.tap(find.text('Career'));
      await tester.pumpAndSettle();
      final trophyFilterText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('career-trophy-filter')),
          matching: find.text('TEAM'),
        ),
      );
      final competitionFilterText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('career-competition-filter')),
          matching: find.text('ALL LEAGUES'),
        ),
      );
      expect(trophyFilterText.style?.color, testCase.foreground);
      expect(competitionFilterText.style?.color, testCase.foreground);
      expect(tester.takeException(), isNull);
    });
  }
}
