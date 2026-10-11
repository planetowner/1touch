import 'dart:async';

import 'support/app_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/full_screen_back_gesture.dart';
import 'package:onetouch/core/interactive_back_page.dart';
import 'package:onetouch/rank_fav_teams.dart';
import 'package:onetouch/select_favorite_teams.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/welcome_loading_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  setUpAppCatalog();
  const phoneSizes = [
    Size(320, 568),
    Size(375, 667),
    Size(393, 852),
    Size(430, 932),
  ];

  testWidgets(
      'swiping the first team keeps the screen fixed and scroll unlocked',
      (tester) async {
    const size = Size(393, 852);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(initialLocation: '/onboarding/welcome', routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const Scaffold(body: Text('Login')),
        routes: [
          GoRoute(
            path: 'welcome',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/onboarding/select-favorites'),
                child: const Text('Welcome'),
              ),
            ),
          ),
          GoRoute(
            path: 'select-favorites',
            pageBuilder: (_, state) => InteractiveBackPage<void>(
              key: state.pageKey,
              child: const SelectFavoriteTeamsScreen(),
            ),
          ),
        ],
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: app_style.darktheme.copyWith(platform: TargetPlatform.iOS),
      routerConfig: router,
      builder: (context, child) => AnimatedBuilder(
        animation: router.routeInformationProvider,
        builder: (context, _) => FullScreenBackGesture(
          child: child!,
        ),
      ),
    ));
    await tester.tap(find.text('Welcome'));
    await tester.pumpAndSettle();

    final logo = find.byKey(const ValueKey('gradient-header-logo'));
    final initialX = tester.getTopLeft(logo).dx;
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
          of: find.byType(PageView), matching: find.byType(Scrollable)),
    );
    bool canScroll() =>
        scrollable.position.physics.shouldAcceptUserOffset(scrollable.position);
    final drag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('favorite-team-logo-region'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await drag.moveBy(const Offset(80, 0));
    await tester.pump();
    expect(tester.getTopLeft(logo).dx, closeTo(initialX, 1));
    expect(canScroll(), isTrue);
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(logo).dx, closeTo(initialX, 1));
    expect(canScroll(), isTrue);
    expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('iOS carousel swipes stay on team selection at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(initialLocation: '/welcome', routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/select-favorites'),
              child: const Text('Welcome'),
            ),
          ),
        ),
        GoRoute(
          path: '/select-favorites',
          pageBuilder: (_, state) => InteractiveBackPage<void>(
            key: state.pageKey,
            child: const SelectFavoriteTeamsScreen(),
          ),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        theme: app_style.darktheme.copyWith(platform: TargetPlatform.iOS),
        routerConfig: router,
        builder: (_, child) => FullScreenBackGesture(child: child!),
      ));
      await tester.tap(find.text('Welcome'));
      await tester.pumpAndSettle();

      final carousel = find.byKey(const ValueKey('favorite-team-logo-region'));
      final pageController =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      await tester.drag(carousel, Offset(-size.width * 0.65, 0));
      await tester.pumpAndSettle();
      expect(pageController.page, 1);
      expect(
          ModalRoute.of(tester.element(carousel))!.popGestureEnabled, isFalse);

      await tester.drag(carousel, Offset(size.width * 0.65, 0));
      await tester.pumpAndSettle();
      expect(pageController.page, 0);
      expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
      expect(
          ModalRoute.of(tester.element(carousel))!.popGestureEnabled, isFalse);
      await tester.dragFrom(
        Offset(24, size.height / 2),
        Offset(size.width * 0.7, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
      expect(find.text('Welcome'), findsNothing);

      await tester.dragFrom(
        Offset(size.width * 0.25, size.height * 0.75),
        Offset(size.width * 0.7, 0),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
      expect(find.text('Welcome'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Android system back works after selecting a later team',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme.copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SelectFavoriteTeamsScreen(),
              ),
            ),
            child: const Text('Open team selection'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open team selection'));
    await tester.pumpAndSettle();
    final carousel = find.byKey(const ValueKey('favorite-team-logo-region'));
    await tester.drag(carousel, const Offset(-260, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SelectFavoriteTeamsScreen), findsNothing);
    expect(find.text('Open team selection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
      final logoRegion = find.byKey(
        const ValueKey('favorite-team-logo-region'),
      );
      final expectedLogoHeight =
          (112 + 108 * ((size.height - 560) / 240).clamp(0.0, 1.0))
              .clamp(150.0, 220.0);
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
      expect(headerLogo.width, 120);
      expect(headerLogo.height, 23);
      expect(
        tester.getSize(logoRegion).height,
        closeTo(expectedLogoHeight, 0.01),
      );
      for (final team in mockTeams.take(2)) {
        final teamLogo = find.byKey(
          ValueKey('favorite-team-logo-${team.teamId}'),
        );
        expect(teamLogo, findsOneWidget);
        final logoSize = tester.getRect(teamLogo).size;
        expect(logoSize.width, closeTo(150, 0.01));
        expect(logoSize.height, closeTo(150, 0.01));
        expect(
          tester
              .widget<Image>(
                find.descendant(of: teamLogo, matching: find.byType(Image)),
              )
              .fit,
          BoxFit.contain,
        );
      }
      expect(toggleIcon.color, app_style.AppPalette.white);
      expect(find.byKey(const ValueKey('favorite-league-trigger-blur')),
          findsOneWidget);
      expect(find.text('PREMIER LEAGUE'), findsOneWidget);
      expect(find.text('Premier League'), findsNothing);

      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byKey(const ValueKey('favorite-league-menu-blur')),
          findsOneWidget);
      expect(find.text('LA LIGA'), findsOneWidget);
      expect(find.text('LaLiga'), findsNothing);
      expect(tester.takeException(), isNull);

      final option = find
          .ancestor(of: find.text('LA LIGA'), matching: find.byType(InkWell))
          .first;
      final menuBounds = tester
          .getRect(find.byKey(const ValueKey('favorite-league-menu-blur')));
      final visibleRight =
          menuBounds.right < size.width ? menuBounds.right : size.width;
      final tapPosition = Offset(visibleRight - 8, tester.getCenter(option).dy);
      // 화면에 보이는 라벨 오른쪽 빈 영역도 리그 선택에 포함돼야 해요.
      expect(tapPosition.dx,
          greaterThan(tester.getRect(find.text('LA LIGA')).right));
      await tester.tapAt(tapPosition);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('favorite-league-menu-blur')),
          findsNothing);
      expect(find.text('LA LIGA'), findsOneWidget);
      expect(find.text('PREMIER LEAGUE'), findsNothing);
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

  for (final size in [const Size(320, 568), const Size(393, 852)]) {
    testWidgets('one selected team skips ranking at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalVideoPlatform = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = _IdleVideoPlatform();
      addTearDown(() => VideoPlayerPlatform.instance = originalVideoPlatform);
      final repository = _RecordingPreferencesRepository();
      final preferences = CurrentUserPreferences(
        repository: repository,
        teamRepository: MockTeamRepository(),
      );
      await tester.pumpWidget(MaterialApp(
        theme: app_style.darktheme,
        home: SelectFavoriteTeamsScreen(preferences: preferences),
      ));
      await tester.pump();

      final team = mockTeams.first;
      final logo = find.byWidgetPredicate((widget) =>
          widget is Image &&
          widget.image is NetworkImage &&
          (widget.image as NetworkImage).url == team.imagePath);
      await tester.tap(logo);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('select-favorites-continue')));
      await tester.pumpAndSettle();

      expect(repository.saved?.favoriteTeamId, team.teamId);
      expect(repository.saved?.followedTeamIds, [team.teamId]);
      expect(find.byType(RankFavoriteTeamsScreen), findsNothing);
      expect(find.byType(WelcomeLoadingScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('failed one-team save stays on selection for retry',
      (tester) async {
    final repository = _RecordingPreferencesRepository()..failSave = true;
    final preferences = CurrentUserPreferences(
      repository: repository,
      teamRepository: MockTeamRepository(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: SelectFavoriteTeamsScreen(preferences: preferences),
    ));
    await tester.pump();

    final team = mockTeams.first;
    final logo = find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is NetworkImage &&
        (widget.image as NetworkImage).url == team.imagePath);
    await tester.tap(logo);
    await tester.pump();
    final continueButton =
        find.byKey(const ValueKey('select-favorites-continue'));
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(repository.saveCalls, 1);
    expect(find.byType(SelectFavoriteTeamsScreen), findsOneWidget);
    expect(find.byType(RankFavoriteTeamsScreen), findsNothing);
    expect(tester.widget<ElevatedButton>(continueButton).onPressed, isNotNull);
    expect(
        find.text('Unable to save teams. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two selected teams still open ranking without saving',
      (tester) async {
    final repository = _RecordingPreferencesRepository();
    final preferences = CurrentUserPreferences(
      repository: repository,
      teamRepository: MockTeamRepository(),
    );
    await tester.pumpWidget(MaterialApp(
      theme: app_style.darktheme,
      home: SelectFavoriteTeamsScreen(preferences: preferences),
    ));
    await tester.pump();

    final firstTeam = mockTeams.first;
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is NetworkImage &&
        (widget.image as NetworkImage).url == firstTeam.imagePath));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    await tester.tap(find.text('LA LIGA'));
    await tester.pump();
    final secondTeam = mockTeams.firstWhere((team) => team.teamId == 83);
    await tester.tap(find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is NetworkImage &&
        (widget.image as NetworkImage).url == secondTeam.imagePath));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('select-favorites-continue')));
    await tester.pumpAndSettle();

    final rank = tester.widget<RankFavoriteTeamsScreen>(
      find.byType(RankFavoriteTeamsScreen),
    );
    expect(rank.selectedTeams.map((team) => team.teamId),
        [firstTeam.teamId, secondTeam.teamId]);
    expect(repository.saveCalls, 0);
    expect(find.byType(WelcomeLoadingScreen), findsNothing);
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

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      testWidgets(
          'team carousel mixes single steps and momentum on $platform at $size',
          (tester) async {
        await _pumpTeamCarousel(tester, platform: platform, size: size);
        final carousel = find.byType(PageView);
        final controller = tester.widget<PageView>(carousel).controller!;
        final pageWidth = size.width * controller.viewportFraction;

        await tester.timedDrag(
          carousel,
          Offset(-pageWidth * 0.7, 0),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();
        expect(controller.page, 1);

        for (final speed in [500.0, 800.0, 1100.0]) {
          controller.jumpToPage(0);
          await tester.pumpAndSettle();
          await tester.fling(carousel, const Offset(-100, 0), speed);
          await tester.pumpAndSettle();
          expect(controller.page, 1,
              reason: 'Single-team swipe at $speed px/s');
        }

        controller.jumpToPage(0);
        await tester.pumpAndSettle();
        await tester.fling(carousel, const Offset(-100, 0), 1800);
        await tester.pumpAndSettle();
        final fastPage = controller.page!;
        expect(fastPage, greaterThan(1));
        expect(fastPage, fastPage.roundToDouble());

        controller.jumpToPage(0);
        await tester.pumpAndSettle();
        await tester.fling(carousel, const Offset(-100, 0), 2800);
        await tester.pumpAndSettle();
        final fasterPage = controller.page!;
        expect(fasterPage, greaterThan(fastPage));
        expect(fasterPage, fasterPage.roundToDouble());
        expect(find.text(mockTeams[fasterPage.toInt()].name), findsOneWidget);

        await tester.fling(carousel, const Offset(100, 0), 1800);
        await tester.pumpAndSettle();
        expect(controller.page, lessThan(fasterPage - 1));
        expect(controller.page, controller.page!.roundToDouble());

        final lastPage = tester
                .widget<PageView>(carousel)
                .childrenDelegate
                .estimatedChildCount! -
            1;
        controller.jumpToPage(lastPage - 1);
        await tester.pumpAndSettle();
        await tester.fling(carousel, const Offset(-100, 0), 5000);
        await tester.pumpAndSettle();
        expect(controller.page, lastPage);

        controller.jumpToPage(1);
        await tester.pumpAndSettle();
        await tester.fling(carousel, const Offset(100, 0), 5000);
        await tester.pumpAndSettle();
        expect(controller.page, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('holding a spinning carousel allows a precise next-team drag',
      (tester) async {
    await _pumpTeamCarousel(tester);
    final carousel = find.byType(PageView);
    final controller = tester.widget<PageView>(carousel).controller!;
    await tester.fling(carousel, const Offset(-100, 0), 2800);
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.position.isScrollingNotifier.value, isTrue);

    final touch = await tester.startGesture(tester.getCenter(carousel));
    final heldPage = controller.page!;
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, heldPage);
    await touch.up();
    await tester.pumpAndSettle();
    final stoppedPage = controller.page!;
    expect(stoppedPage, stoppedPage.roundToDouble());
    expect(
      tester
          .widget<ElevatedButton>(
            find.byKey(const ValueKey('select-favorites-continue')),
          )
          .onPressed,
      isNull,
    );

    await tester.timedDrag(
      carousel,
      Offset(-tester.getSize(carousel).width * controller.viewportFraction, 0),
      const Duration(seconds: 1),
    );
    await tester.pumpAndSettle();
    expect(controller.page, stoppedPage + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching league stops momentum at the new league first team',
      (tester) async {
    await _pumpTeamCarousel(tester);
    final carousel = find.byType(PageView);
    final controller = tester.widget<PageView>(carousel).controller!;
    await tester.fling(carousel, const Offset(-100, 0), 2800);
    await tester.pump(const Duration(milliseconds: 120));
    expect(controller.position.isScrollingNotifier.value, isTrue);

    await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
    await tester.pump();
    await tester.tap(find.text('LA LIGA'));
    await tester.pumpAndSettle();
    expect(controller.page, 0);
    expect(find.text('FC Barcelona'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a gentle swipe during momentum stops at the next team',
      (tester) async {
    await _pumpTeamCarousel(tester);
    final carousel = find.byType(PageView);
    final controller = tester.widget<PageView>(carousel).controller!;
    await tester.fling(carousel, const Offset(-100, 0), 2800);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.position.isScrollingNotifier.value, isTrue);

    await tester.fling(carousel, const Offset(-100, 0), 800);
    final releasedPage = controller.page!;
    await tester.pumpAndSettle();
    expect(controller.page, releasedPage.ceilToDouble());
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

  testWidgets('rank cards stay fixed while vertical gaps respond to height',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final teams = mockTeams.take(5).toList();

    Future<
        ({
          double gap,
          double fontSize,
          double gradientBottom,
          double thirdTop,
          double fourthTop
        })> pumpAtHeight(double height) async {
      tester.view.physicalSize = Size(393, height);
      await tester.pumpWidget(
        MaterialApp(
          theme: app_style.darktheme,
          home: RankFavoriteTeamsScreen(selectedTeams: teams),
        ),
      );
      await tester.pump();

      final card = find.byKey(ValueKey('rank-team-card-${teams.first.teamId}'));
      final item =
          tester.widget<Container>(find.byKey(ValueKey(teams.first.teamId)));
      final teamName = tester.widget<Text>(
        find.byKey(ValueKey('rank-team-name-${teams.first.teamId}')),
      );
      final logo = find.byKey(ValueKey('rank-team-logo-${teams.first.teamId}'));
      final margin = item.margin! as EdgeInsets;

      expect(tester.getSize(card).height, 72);
      expect(tester.getSize(logo).height, greaterThan(72));
      expect(tester.takeException(), isNull);
      return (
        gap: margin.bottom,
        fontSize: teamName.style!.fontSize!,
        gradientBottom: tester
            .getBottomLeft(
              find.byKey(const ValueKey('rank-favorites-top-gradient')),
            )
            .dy,
        thirdTop: tester
            .getTopLeft(
              find.byKey(ValueKey('rank-team-card-${teams[2].teamId}')),
            )
            .dy,
        fourthTop: tester
            .getTopLeft(
              find.byKey(ValueKey('rank-team-card-${teams[3].teamId}')),
            )
            .dy,
      );
    }

    final compact = await pumpAtHeight(568);
    final tall = await pumpAtHeight(852);

    expect(compact.gap, 4);
    expect(tall.gap, 20);
    expect(tall.gap, greaterThan(compact.gap));
    expect(tall.fontSize, compact.fontSize);
    for (final layout in [compact, tall]) {
      expect(layout.gradientBottom, greaterThan(layout.thirdTop));
      expect(layout.gradientBottom, lessThan(layout.fourthTop));
    }
  });

  testWidgets('first ranked team can move down and another team can move up',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final teams = mockTeams.take(3).toList();
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.darktheme,
        home: RankFavoriteTeamsScreen(selectedTeams: teams),
      ),
    );
    await tester.pumpAndSettle();

    Finder card(int index) =>
        find.byKey(ValueKey('rank-team-card-${teams[index].teamId}'));
    Finder handle(int index) =>
        find.byKey(ValueKey('rank-team-drag-handle-${teams[index].teamId}'));
    Finder star(int index) => find.descendant(
          of: find.byKey(ValueKey(teams[index].teamId)),
          matching: find.byIcon(Icons.star),
        );

    Future<void> moveTeam(int source, int target) async {
      final start = tester.getCenter(handle(source));
      final end = Offset(start.dx, tester.getCenter(card(target)).dy);
      final drag = await tester.startGesture(start);
      await tester.pump(const Duration(milliseconds: 200));
      await drag.moveTo(end);
      await tester.pump(const Duration(milliseconds: 300));
      await drag.up();
      await tester.pumpAndSettle();
    }

    await moveTeam(0, 2);
    expect(
        tester.getTopLeft(card(1)).dy, lessThan(tester.getTopLeft(card(0)).dy));
    expect(star(1), findsOneWidget);
    expect(star(0), findsNothing);

    await moveTeam(2, 1);
    expect(
        tester.getTopLeft(card(2)).dy, lessThan(tester.getTopLeft(card(1)).dy));
    expect(star(2), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        319,
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
      final dragHandle = tester.widget<Icon>(
        find.byKey(ValueKey('rank-team-drag-handle-${firstTeam.teamId}')),
      );
      expect(dragHandle.color, app_style.AppPalette.white);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpTeamCarousel(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.iOS,
  Size size = const Size(375, 667),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: app_style.darktheme.copyWith(platform: platform),
    home: const SelectFavoriteTeamsScreen(),
  ));
  await tester.pumpAndSettle();
}

class _RecordingPreferencesRepository implements UserPreferencesRepository {
  UserTeamPreferences? saved;
  int saveCalls = 0;
  bool failSave = false;

  @override
  Future<UserTeamPreferences?> load() async => null;

  @override
  Future<void> save(UserTeamPreferences preferences) async {
    saveCalls++;
    if (failSave) throw StateError('Save failed');
    saved = preferences;
  }
}

class _IdleVideoPlatform extends VideoPlayerPlatform {
  final _events = StreamController<VideoEvent>.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => 1;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => _events.stream;

  @override
  Future<void> dispose(int playerId) => _events.close();
}
