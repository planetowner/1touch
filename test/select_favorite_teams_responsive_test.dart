import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/RankFavTeams.dart';
import 'package:onetouch/Select_Favorite_Teams.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/teams/mock/team_catalog.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
  ];

  for (final size in phoneSizes) {
    testWidgets('fits a ${size.width}x${size.height} viewport', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: const SelectFavoriteTeamsScreen(),
        ),
      );
      await tester.pump();

      final headerLogo = tester.widget<SvgPicture>(
        find.byKey(const ValueKey('gradient-header-logo')),
      );
      final toggleIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('gradient-header-theme-toggle')),
          matching: find.byIcon(Icons.brightness_4_outlined),
        ),
      );
      expect(
        headerLogo.colorFilter,
        const ColorFilter.mode(app_style.AppPalette.white, BlendMode.srcIn),
      );
      expect(toggleIcon.color, app_style.AppPalette.white);
      expect(find.text('PREMIER LEAGUE'), findsOneWidget);
      expect(find.text('Premier League'), findsNothing);

      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsWidgets);
      expect(find.text('LALIGA'), findsOneWidget);
      expect(find.text('LaLiga'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selected team chip uses the full name and is centered',
      (tester) async {
    const size = Size(320, 568);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const SelectFavoriteTeamsScreen(),
      ),
    );
    await tester.pump();

    final team = mockTeams.first;
    final teamLogo = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is NetworkImage &&
          (widget.image as NetworkImage).url == team.imagePath,
    );
    await tester.tap(teamLogo);
    await tester.pump();

    final chip = find.byKey(ValueKey('selected-team-${team.teamId}'));
    final name = find.descendant(of: chip, matching: find.text(team.name));
    final nameText = tester.widget<Text>(name);

    expect(chip, findsOneWidget);
    expect(nameText.data, team.name);
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(tester.getCenter(chip).dx, closeTo(size.width / 2, 0.5));
    expect(tester.getSize(chip).width, lessThanOrEqualTo(size.width - 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('team carousel snaps to the closest team', (tester) async {
    const size = Size(375, 667);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const SelectFavoriteTeamsScreen(),
      ),
    );
    await tester.pump();

    final carousel = find.byType(PageView);
    expect(find.text('Manchester City'), findsOneWidget);

    await tester.timedDrag(
      carousel,
      const Offset(-80, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Manchester City'), findsOneWidget);

    await tester.timedDrag(
      carousel,
      const Offset(-150, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(find.text('Arsenal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rank favorites returns to team selection at compact width',
      (tester) async {
    const size = Size(320, 568);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: const SelectFavoriteTeamsScreen(),
      ),
    );
    await tester.pump();

    final selectContext =
        tester.element(find.byType(SelectFavoriteTeamsScreen));
    Navigator.of(selectContext).push(
      MaterialPageRoute<void>(
        builder: (_) => RankFavoriteTeamsScreen(
          selectedTeams: mockTeams.take(3).toList(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backButton = find.byKey(const ValueKey('rank-favorites-back-button'));
    final backIcon = tester.widget<Icon>(
      find.descendant(of: backButton, matching: find.byType(Icon)),
    );
    expect(backButton, findsOneWidget);
    expect(backIcon.color, app_style.AppPalette.white);
    expect(find.byKey(const ValueKey('gradient-header-logo')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byType(RankFavoriteTeamsScreen), findsNothing);
    expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('rank cards scale and crop crests at ${size.height}px tall',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final teams = mockTeams.take(5).toList();
      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: RankFavoriteTeamsScreen(selectedTeams: teams),
        ),
      );
      await tester.pump();

      final card = find.byKey(ValueKey('rank-team-card-${teams.first.teamId}'));
      final logo = find.byKey(ValueKey('rank-team-logo-${teams.first.teamId}'));
      final cardHeight = tester.getSize(card).height;

      expect(cardHeight, inInclusiveRange(64, 72));
      expect(tester.getSize(logo).height, greaterThan(cardHeight));
      expect(tester.takeException(), isNull);
    });
  }

  for (final testCase in <({ThemeData theme, Color background})>[
    (theme: app_style.darktheme, background: app_style.AppPalette.black),
    (theme: app_style.whitetheme, background: app_style.AppPalette.white),
  ]) {
    testWidgets('rank favorites uses a solid theme background', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: RankFavoriteTeamsScreen(
            selectedTeams: mockTeams.take(3).toList(),
          ),
        ),
      );
      await tester.pump();

      final backgroundFinder =
          find.byKey(const ValueKey('rank-favorites-background'));
      final background = tester.widget<ColoredBox>(backgroundFinder);
      final topGradient = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('rank-favorites-top-gradient')),
      );
      final gradient =
          (topGradient.decoration as BoxDecoration).gradient as LinearGradient;
      final toggleIcon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(const ValueKey('gradient-header-theme-toggle')),
          matching: find.byIcon(Icons.brightness_4_outlined),
        ),
      );
      expect(background.color, testCase.background);
      expect(tester.getTopLeft(backgroundFinder), Offset.zero);
      expect(tester.getSize(backgroundFinder), const Size(320, 568));
      expect(gradient.colors.first, app_style.AppPalette.lightGrey);
      expect(gradient.colors.last, Colors.transparent);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('rank-favorites-top-gradient')),
            )
            .height,
        550,
      );
      expect(find.byKey(const ValueKey('gradient-header-logo')), findsNothing);
      expect(toggleIcon.color, app_style.AppPalette.white);

      final firstTeam = mockTeams.first;
      final teamName = tester.widget<Text>(
        find.byKey(ValueKey('rank-team-name-${firstTeam.teamId}')),
      );
      final teamPosition = tester.widget<Text>(
        find.byKey(ValueKey('rank-team-position-${firstTeam.teamId}')),
      );
      expect(teamName.style?.color, app_style.AppPalette.white);
      expect(teamPosition.style?.color, app_style.AppPalette.white);
      expect(tester.takeException(), isNull);
    });
  }
}
