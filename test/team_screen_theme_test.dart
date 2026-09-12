import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/StandingFeatures.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/data/team_attributes/mock/mock_team_attribute_repository.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/screens/TeamScreen.dart';

Color? _effectiveTextColor(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final text = tester.widget<Text>(finder);
  return DefaultTextStyle.of(element).style.merge(text.style).color;
}

void main() {
  final teamAttributeRepository = MockTeamAttributeRepository();
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
              home: TeamScreen(
                teamId: 9,
                teamAttributeRepository: teamAttributeRepository,
              ),
            ),
          );
          await tester.pump();

          final context = tester.element(find.byType(Scaffold));
          final colorScheme = Theme.of(context).colorScheme;
          final tabBar = tester.widget<TabBar>(find.byType(TabBar));
          final appBar = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
          final expectedGradientHeight =
              (size.height * 0.70).clamp(550.0, 650.0).toDouble();

          expect(
            tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
            app_style.mainPageBackground(context),
          );
          expect(tabBar.labelColor, colorScheme.onSurface);
          expect(tabBar.indicatorColor, colorScheme.onSurface);
          expect(appBar.foregroundColor, app_style.AppPalette.white);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('team-brand-gradient')))
                .height,
            expectedGradientHeight,
          );
          expect(tester.takeException(), isNull);

          final tabView = find.byType(TabBarView);
          for (var index = 1; index < 5; index++) {
            await tester.drag(tabView, Offset(-size.width, 0));
            await tester.pump(const Duration(milliseconds: 350));
            if (index == 1) {
              await tester.pump();
            }
            if (index == 3) {
              await tester.pump(const Duration(milliseconds: 450));
            }
            if (index == 1) {
              final headerStack = find.byKey(
                const ValueKey('matches-header-stack'),
              );
              final upcomingHeader = find.byKey(
                const ValueKey('matches-upcoming-header'),
              );
              final matchesScroll = find.byKey(
                const ValueKey('matches-scroll'),
              );

              expect(headerStack, findsOneWidget);
              expect(upcomingHeader, findsOneWidget);
              expect(matchesScroll, findsOneWidget);
              expect(
                find.descendant(
                  of: upcomingHeader,
                  matching: find.byWidgetPredicate(
                    (widget) =>
                        widget is Container &&
                        widget.color == Colors.transparent,
                  ),
                ),
                findsOneWidget,
              );
              expect(
                find.descendant(
                  of: matchesScroll,
                  matching: upcomingHeader,
                ),
                findsNothing,
              );
              expect(
                tester.getBottomLeft(headerStack).dy,
                closeTo(tester.getTopLeft(matchesScroll).dy, 0.1),
              );
            }
            if (index == 2) {
              final filterRow = find.byKey(
                const ValueKey('standing-filter-row'),
              );
              final leagueShell = find.byKey(
                const ValueKey('standing-league-filter-shell'),
              );
              final seasonShell = find.byKey(
                const ValueKey('standing-season-filter-shell'),
              );
              final toggle = find.byKey(
                const ValueKey('standing-view-toggle'),
              );
              final leagueFilter = tester.widget<DropdownButton<int>>(
                find.byKey(const ValueKey('standing-league-filter')),
              );
              final seasonFilter = tester.widget<DropdownButton<int>>(
                find.byKey(const ValueKey('standing-season-filter')),
              );
              final filterLabels = [
                ...leagueFilter.items!.map(
                  (item) => (item.child as Text).data!,
                ),
                ...seasonFilter.items!.map(
                  (item) => (item.child as Text).data!,
                ),
              ];

              expect(
                filterLabels,
                everyElement(
                  predicate<String>((label) => label == label.toUpperCase()),
                ),
              );
              expect(
                tester.getSize(filterRow).width,
                closeTo(size.width - 48, 0.1),
              );
              expect(
                tester.getSize(leagueShell).width,
                closeTo((size.width - 64) / 2, 0.1),
              );
              expect(
                tester.getSize(seasonShell).width,
                closeTo((size.width - 64) / 2, 0.1),
              );
              expect(
                find.descendant(
                  of: filterRow,
                  matching: find.byType(SingleChildScrollView),
                ),
                findsNothing,
              );
              expect(toggle, findsOneWidget);
              expect(
                tester.getSize(toggle).width,
                closeTo(size.width - 48, 0.1),
              );
              expect(
                find.descendant(
                  of: toggle,
                  matching: find.byIcon(Icons.keyboard_arrow_down),
                ),
                findsNothing,
              );

              await tester.ensureVisible(toggle);
              await tester.pump();
              await tester.tap(
                find.byKey(const ValueKey('standing-view-xg-table')),
              );
              await tester.pump();
              expect(find.byType(XgTable), findsOneWidget);
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

  testWidgets('Team header fits a 430x932 viewport', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: TeamScreen(
          teamId: 9,
          teamAttributeRepository: teamAttributeRepository,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('team-search-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Team tabs use black foregrounds in light mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(
          teamId: 9,
          teamAttributeRepository: teamAttributeRepository,
        ),
      ),
    );
    await tester.pump();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    final indicator = tabBar.indicator! as UnderlineTabIndicator;
    final appColors =
        app_style.AppColors.of(tester.element(find.byType(TabBar)));
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
    expect(indicator.borderSide.width, 2);
    expect(tabBar.padding, const EdgeInsets.only(left: 8));
    expect(find.byKey(const Key('team-profile-button')), findsNothing);
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

  testWidgets('xG table segment is disabled when the league has no xG data',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: StandingViewToggle(
            selectedView: StandingView.standing,
            availableViews: const [StandingView.standing],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final xgSegment = tester.widget<InkWell>(
      find.byKey(const ValueKey('standing-view-xg-table')),
    );

    expect(xgSegment.onTap, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standing toggle rounds both segment surfaces', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: StandingViewToggle(
            selectedView: StandingView.xgTable,
            availableViews: StandingView.values,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    final standingSurface = tester.widget<Material>(
      find.byKey(const ValueKey('standing-view-standing-surface')),
    );
    final xgSurface = tester.widget<Material>(
      find.byKey(const ValueKey('standing-view-xg-table-surface')),
    );
    final toggle = tester.widget<Container>(
      find.byKey(const ValueKey('standing-view-toggle')),
    );
    final indicator = tester.widget<AnimatedAlign>(
      find.byKey(const ValueKey('standing-view-indicator')),
    );
    final indicatorSurface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('standing-view-indicator-surface')),
    );

    expect(toggle.padding, const EdgeInsets.all(2));
    expect(
      (toggle.decoration as BoxDecoration).color,
      app_style.AppPalette.lightGrey,
    );
    expect(standingSurface.color, Colors.transparent);
    expect(xgSurface.color, Colors.transparent);
    expect(indicator.alignment, Alignment.centerRight);
    expect(indicator.duration, const Duration(milliseconds: 180));
    expect(indicator.curve, Curves.easeOutCubic);
    expect(
      indicatorSurface.decoration,
      const BoxDecoration(
        color: app_style.AppPalette.black,
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    );
    expect(
      standingSurface.borderRadius,
      const BorderRadius.all(Radius.circular(6)),
    );
    expect(
      xgSurface.borderRadius,
      const BorderRadius.all(Radius.circular(6)),
    );
    expect(standingSurface.clipBehavior, Clip.antiAlias);
    expect(xgSurface.clipBehavior, Clip.antiAlias);
    expect(tester.takeException(), isNull);
  });

  testWidgets('standing indicator slides smoothly between table types',
      (tester) async {
    var selectedView = StandingView.xgTable;

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => StandingViewToggle(
              selectedView: selectedView,
              availableViews: StandingView.values,
              onChanged: (view) => setState(() => selectedView = view),
            ),
          ),
        ),
      ),
    );

    final indicator =
        find.byKey(const ValueKey('standing-view-indicator-surface'));
    final startX = tester.getTopLeft(indicator).dx;

    await tester.tap(
      find.byKey(const ValueKey('standing-view-standing')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final middleX = tester.getTopLeft(indicator).dx;
    await tester.pump(const Duration(milliseconds: 100));
    final endX = tester.getTopLeft(indicator).dx;

    expect(middleX, lessThan(startX));
    expect(middleX, greaterThan(endX));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Team fixture sections use the approved dark surfaces',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: TeamScreen(
          teamId: 9,
          teamAttributeRepository: teamAttributeRepository,
        ),
      ),
    );
    await tester.pump();

    final nextMatch = tester.widget<MatchCard>(find.byType(MatchCard));
    final lastMatch = tester.widget<MatchCard2>(find.byType(MatchCard2));
    final fixturesCard = tester.widget<Container>(
      find.byKey(const ValueKey('team-overview-fixtures-card')),
    );

    expect(nextMatch.backgroundColor, app_style.AppPalette.lightGrey);
    expect(lastMatch.backgroundColor, app_style.AppPalette.darkGrey);
    expect(
      (fixturesCard.decoration as BoxDecoration).color,
      app_style.AppPalette.darkGrey,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('match section headers accumulate in fixture order',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: TeamScreen(
          teamId: 9,
          teamAttributeRepository: teamAttributeRepository,
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.byType(TabBarView), const Offset(-393, 0));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final matchesScrollFinder = find.byKey(
      const ValueKey('matches-scroll'),
    );
    final matchesScroll = tester.widget<CustomScrollView>(
      matchesScrollFinder,
    );
    final controller = matchesScroll.controller!;

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('matches-past-header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('matches-inline-live-header')),
      findsOneWidget,
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
      findsOneWidget,
    );
    expect(
      find
              .byKey(const ValueKey('matches-inline-past-header'))
              .evaluate()
              .length +
          find.byKey(const ValueKey('matches-past-header')).evaluate().length,
      1,
    );

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final upcomingHeader = find.byKey(
      const ValueKey('matches-upcoming-header'),
    );
    final liveHeader = find.byKey(
      const ValueKey('matches-live-header'),
    );
    final pastHeader = find.byKey(
      const ValueKey('matches-past-header'),
    );

    expect(upcomingHeader, findsOneWidget);
    expect(liveHeader, findsOneWidget);
    expect(pastHeader, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('matches-header-stack')),
        matching: find.byType(AnimatedSize),
      ),
      findsNothing,
    );
    final headerSlides = tester.widgetList<AnimatedSlide>(
      find.descendant(
        of: find.byKey(const ValueKey('matches-header-stack')),
        matching: find.byType(AnimatedSlide),
      ),
    );
    expect(
      headerSlides.map((animation) => animation.duration),
      everyElement(const Duration(milliseconds: 140)),
    );
    expect(
      tester.getTopLeft(upcomingHeader).dy,
      lessThan(tester.getTopLeft(liveHeader).dy),
    );
    expect(
      tester.getTopLeft(liveHeader).dy,
      lessThan(tester.getTopLeft(pastHeader).dy),
    );

    controller.jumpTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      find.byKey(const ValueKey('matches-upcoming-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('matches-live-header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('matches-past-header')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Standing and Analysis filters use black text in light mode',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: TeamScreen(
          teamId: 9,
          teamAttributeRepository: teamAttributeRepository,
        ),
      ),
    );
    await tester.pump();

    final tabView = find.byType(TabBarView);
    await tester.drag(tabView, const Offset(-393, 0));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(tabView, const Offset(-393, 0));
    await tester.pump(const Duration(milliseconds: 350));

    final leagueFilter = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-league-filter')),
    );
    final seasonFilter = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('standing-season-filter')),
    );
    expect(leagueFilter.style?.color, app_style.AppPalette.black);
    expect(seasonFilter.style?.color, app_style.AppPalette.black);
    expect(
      _effectiveTextColor(tester, find.text('STANDING').first),
      app_style.AppPalette.white,
    );
    expect(
      _effectiveTextColor(tester, find.text('XG TABLE')),
      app_style.AppPalette.black,
    );

    await tester.drag(tabView, const Offset(-393, 0));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.drag(tabView, const Offset(-393, 0));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final attributesFilter = tester.widget<DropdownButton<int>>(
      find.byKey(const ValueKey('analysis-attributes-filter')),
    );
    final formationFilter = tester.widget<DropdownButton<String>>(
      find.byKey(const ValueKey('analysis-formation-filter')),
    );
    final formFilter = tester.widget<DropdownButton<CurrentFormOption>>(
      find.byKey(const ValueKey('analysis-form-filter')),
    );

    expect(attributesFilter.style?.color, app_style.AppPalette.black);
    expect(formationFilter.style?.color, app_style.AppPalette.black);
    expect(formFilter.style?.color, app_style.AppPalette.black);
    for (final item in attributesFilter.items!) {
      final label = (item.child as Text).data!;
      expect(label, label.toUpperCase());
    }
    for (final item in formationFilter.items!) {
      final label = (item.child as Text).data!;
      expect(label, label.toUpperCase());
    }
    for (final item in formFilter.items!) {
      final labels = (item.child as Row).children.whereType<Text>();
      for (final text in labels) {
        expect(text.data, text.data!.toUpperCase());
      }
    }
    await tester.pump(const Duration(milliseconds: 450));
    expect(tester.takeException(), isNull);
  });
}
