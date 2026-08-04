import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/screens/TeamScreen.dart';

void main() {
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
  ];

  for (final testCase in <({String name, ThemeData theme})>[
    (name: 'dark', theme: app_style.darktheme),
    (name: 'light', theme: app_style.whitetheme),
  ]) {
    for (final size in phoneSizes) {
      testWidgets(
        'Team tabs fit ${size.width}x${size.height} in ${testCase.name} mode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            MaterialApp(
              theme: testCase.theme,
              home: TeamScreen(teamId: 9),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(Scaffold));
          final colorScheme = Theme.of(context).colorScheme;
          final appColors = app_style.AppColors.of(context);
          final tabBar = tester.widget<TabBar>(find.byType(TabBar));
          final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));

          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            app_style.mainPageBackground(context),
          );
          expect(tabBar.labelColor, colorScheme.onSurface);
          expect(tabBar.indicatorColor, colorScheme.onSurface);
          expect(appBar.foregroundColor, app_style.AppPalette.white);
          expect(tester.takeException(), isNull);

          final tabView = find.byType(TabBarView);
          for (var index = 1; index < 5; index++) {
            await tester.drag(tabView, Offset(-size.width, 0));
            await tester.pump(const Duration(milliseconds: 350));
            if (index == 3) {
              await tester.pump(const Duration(milliseconds: 450));
            }
            final tabException = tester.takeException();
            expect(
              tabException,
              isNull,
              reason: 'tab index $index must not overflow',
            );
          }
        },
      );
    }
  }

  testWidgets('Team tabs use black foregrounds in light mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(teamId: 9),
      ),
    );
    await tester.pump();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final indicator = tabBar.indicator! as UnderlineTabIndicator;
    final appColors =
        app_style.AppColors.of(tester.element(find.byType(TabBar)));
    final followIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('team-follow-button')),
        matching: find.byType(Icon),
      ),
    );
    final profileIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('team-profile-button')),
        matching: find.byType(Icon),
      ),
    );
    final searchIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('team-search-button')),
        matching: find.byType(Icon),
      ),
    );
    final nextMatch = tester.widget<MatchCard>(find.byType(MatchCard));
    final lastMatch = tester.widget<MatchCard2>(find.byType(MatchCard2));
    final fixturesCard = tester.widget<Container>(
      find.byKey(const ValueKey('team-overview-fixtures-card')),
    );

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -420),
    );
    await tester.pump();

    final standingCard = tester.widget<Container>(
      find.byKey(const ValueKey('overview-standing-card-8')),
    );
    final standingHeader = tester.widget<Container>(
      find.byKey(const ValueKey('overview-standing-header-8')),
    );

    expect(tabBar.labelColor, app_style.AppPalette.black);
    expect(tabBar.indicatorColor, app_style.AppPalette.black);
    expect(indicator.borderSide.color, app_style.AppPalette.black);
    expect(followIcon.color, app_style.AppPalette.white);
    expect(profileIcon.color, app_style.AppPalette.white);
    expect(searchIcon.color, app_style.AppPalette.white);
    expect(nextMatch.backgroundColor, app_style.AppPalette.white);
    expect(lastMatch.backgroundColor, app_style.AppPalette.lightGreyBox);
    expect(
      lastMatch.contentPadding,
      const EdgeInsets.fromLTRB(16, 16, 16, 24),
    );
    expect(fixturesCard.padding, EdgeInsets.zero);
    expect(
      (standingCard.decoration as BoxDecoration).color,
      app_style.AppPalette.lightGreyBox,
    );
    expect(standingHeader.color, app_style.AppPalette.white);
    expect(tabBar.unselectedLabelColor, appColors.mutedForeground);
    expect(tester.takeException(), isNull);
  });
}
