import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/main.dart';
import 'package:onetouch/core/bottom_navigation.dart';
import 'package:onetouch/features/community/community_access.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/home_screen.dart';
import 'package:onetouch/screens/team_screen.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';

import 'support/app_fonts.dart';
import 'support/profile_activity_fixture.dart';
import 'support/screen_pixels.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('Home selection reaches retained Team and Community tabs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.padding = FakeViewPadding(top: 59);
    tester.view.viewPadding = FakeViewPadding(top: 59);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    final requests = <http.Request>[];
    final catalog =
        jsonDecode(File('test/fixtures/api_catalog.json').readAsStringSync())
            as Map<String, dynamic>;
    (catalog['memberships'] as List).add({
      'team_id': 19,
      'season_id': 28083,
      'competition_id': 8,
    });
    final teams = (catalog['teams'] as List).cast<Map<String, dynamic>>();
    Map<String, dynamic> team(int id) =>
        teams.singleWhere((team) => team['team_id'] == id);
    http.runWithClient(
      () => apiClient.baseUri,
      () => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final teamId =
            int.tryParse(request.url.queryParameters['team_id'] ?? '');
        Object body;
        if (path == '/v1/catalog') {
          body = catalog;
        } else if (path.startsWith('/v1/football-names/')) {
          body = {
            'teams': {},
            'team_short_names': {},
            'players': {},
            'player_short_names': {},
            'competitions': {},
            'countries': {},
            'coaches': {},
          };
        } else if (path == '/v1/users/me') {
          body = {
            'user_id': 1,
            'username': 'example',
            'display_name': 'Example',
            'first_name': 'First',
            'last_name': 'Last',
            'email': null,
            'avatar_url': null,
            'favorite_team_id': 8,
            'created_at': '2026-09-22T00:00:00Z',
            'onboarding_complete': true,
          };
        } else if (path == '/v1/users/me/following/teams') {
          body = teams;
        } else if (path == '/v1/users/me/following/players') {
          body = {'items': []};
        } else if (path == '/v1/home') {
          body = {
            'favorite_team': team(teamId ?? 8),
            'following_teams': teams,
            'next_match': null,
            'last_match': null,
            'calendar': [],
            'highlights': null,
          };
        } else if (RegExp(r'^/v1/teams/\d+$').hasMatch(path)) {
          body = {
            'team': team(int.parse(request.url.pathSegments.last)),
            'next_match': null,
            'last_match': null,
            'standing': null,
          };
        } else if (path == '/v1/posts') {
          body = {'items': [], 'limit': 50, 'offset': 0};
        } else if (path == '/v1/users/me/posts') {
          body = activityPageJson([
            {
              ...activityPostJson(),
              'team_id': 8,
              'avatar_url': null,
              'body': List.filled(25, 'Scrollable post content').join('\n'),
            },
          ]);
        } else if (path == '/v1/posts/42/comments') {
          body = {'items': [], 'limit': 50, 'after_id': 0};
        } else if (path == '/v1/community/followers') {
          body = {'team_id': teamId, 'follower_count': 3};
        } else if (path == '/v1/users/me/points/initialize') {
          body = {'balance': 1000, 'initialized': true, 'welcome_points': 1000};
        } else if (path == '/v1/users/me/notification-preferences') {
          body = {
            'community': {'post_reactions': true, 'post_comments': true},
            'teams': <String, Object>{},
            'players': <String, Object>{},
          };
        } else {
          // 이 테스트에서 다루지 않는 부가 콘텐츠는 기존 오류 상태로 표시해요.
          return http.Response('{"detail":"Unavailable test content"}', 503);
        }
        return http.Response(jsonEncode(body), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );
    authSession.establish('viewed-team-test');
    const captureKey = ValueKey('app-capture');
    await tester
        .pumpWidget(const RepaintBoundary(key: captureKey, child: MyApp()));
    final router = tester
        .widget<MaterialApp>(find.byType(MaterialApp))
        .routerConfig! as GoRouter;
    router.go('/session');
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Example United'), findsOneWidget);

    Future<void> tab(int index) async {
      await tester.tap(find.byKey(ValueKey('main-bottom-navigation-$index')));
      await tester.pumpAndSettle();
    }

    // 먼저 두 탭을 열어둬야 처음 로드할 때뿐 아니라 유지된 화면도 바뀌는지 확인해요.
    await tab(1);
    expect(router.routeInformationProvider.value.uri.path, '/team');
    expect(tester.widget<TeamScreen>(find.byType(TeamScreen)).teamId, 8);
    router.go('/team/8');
    await tester.pumpAndSettle();
    expect(router.canPop(), isTrue);
    tester.widget<TabBar>(find.byType(TabBar)).controller!.animateTo(2);
    await tester.pumpAndSettle();
    await tab(1);
    expect(router.routeInformationProvider.value.uri.path, '/team');
    expect(router.canPop(), isFalse);
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    await tab(3);
    expect(tester.widget<Community>(find.byType(Community)).teamId, 8);
    final communityState = tester.state(find.byType(Community));

    for (final id in [19, 8, 19]) {
      await tab(0);
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pumpAndSettle();
      await tester.tap(find.text(team(id)['name'] as String).last);
      await tester.tap(find.text('SWITCH'));
      await tester.pumpAndSettle();
      expect(currentUserPreferences.viewedTeamId.value, id);

      await tab(1);
      expect(router.routeInformationProvider.value.uri.path, '/team');
      expect(tester.widget<TeamScreen>(find.byType(TeamScreen)).teamId, id);
      await tab(3);
      expect(tester.widget<Community>(find.byType(Community)).teamId, id);
      expect(find.byType(CommunityReadOnlyNotice),
          id == 8 ? findsNothing : findsOneWidget);
      expect(find.byType(FloatingActionButton),
          id == 8 ? findsOneWidget : findsNothing);
      expect(tester.state(find.byType(Community)), same(communityState));
      if (id == 19) {
        final notice =
            find.byKey(const ValueKey('community-read-only-rule-notice'));
        final close = find.descendant(
          of: notice,
          matching: find.byKey(const ValueKey('app-rule-notice-close')),
        );
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(notice, findsNothing);
        await tab(3);
        expect(notice, findsNothing);
        await tab(0);
        await tab(3);
        expect(notice, findsOneWidget);
        expect(tester.state(find.byType(Community)), same(communityState));
      }
      expect(
        requests.any((request) =>
            request.url.path == '/v1/posts' &&
            request.url.queryParameters['team_id'] == '$id'),
        isTrue,
      );
      expect(currentUserPreferences.favoriteTeamId.value, 8);
      expect(currentUserPreferences.followedTeamIds.value, [8, 19]);
    }
    await tab(2);
    expect(router.routeInformationProvider.value.uri.path, '/players');

    router.go('/profile');
    await tester.pumpAndSettle();
    appThemeController.value = ThemeMode.light;
    addTearDown(() => appThemeController.value = ThemeMode.dark);
    await tester.pumpAndSettle();
    Future<void> expectSurface(Color color, String name) async {
      final scaffold = find.byType(Scaffold).last;
      expect(tester.getRect(scaffold).top, 0);
      final pixels = await screenPixels(tester, find.byKey(captureKey),
          [const Offset(8, 2), const Offset(8, 60)],
          screenshotName: name);
      expect(pixels, [color, color]);
    }

    await expectSurface(app_style.AppPalette.lightModeDarkGrey, 'profile');
    Future<Rect> expectEditorAboveNavigation(
        Finder editButton, Key sheetKey) async {
      await tester.ensureVisible(editButton);
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      final sheet = find.byKey(sheetKey);
      final navigation = find.byType(OneTouchBottomNavigationBar);
      expect(sheet, findsOneWidget);
      expect(navigation, findsOneWidget);
      final search = find.byKey(
          sheetKey == const ValueKey('profile-team-edit-sheet')
              ? const ValueKey('profile-team-edit-search')
              : const ValueKey('following-players-search'));
      final fade = find.byKey(
          sheetKey == const ValueKey('profile-team-edit-sheet')
              ? const ValueKey('profile-team-edit-top-fade')
              : const ValueKey('following-list-top-fade'));
      expect(tester.getRect(search).bottom, tester.getRect(fade).top);
      final sheetRect = tester.getRect(sheet);
      expect(
          sheetRect.bottom, lessThanOrEqualTo(tester.getRect(navigation).top));
      Navigator.of(tester.element(sheet)).pop();
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(router.routeInformationProvider.value.uri.path, '/profile');
      return sheetRect;
    }

    final teamEditorRect = await expectEditorAboveNavigation(
      find.byIcon(Icons.border_color).first,
      const ValueKey('profile-team-edit-sheet'),
    );
    final playerEditorRect = await expectEditorAboveNavigation(
      find.descendant(
        of: find.byKey(const ValueKey('players-favorites-section')),
        matching: find.byIcon(Icons.border_color),
      ),
      const ValueKey('following-players-sheet'),
    );
    expect(teamEditorRect.top, closeTo(playerEditorRect.top, 1));
    expect(teamEditorRect.height, closeTo(playerEditorRect.height, 1));
    router.push('/profile/preference');
    await tester.pumpAndSettle();
    await expectSurface(app_style.AppPalette.white, 'preferences');
    Navigator.of(tester.element(find.text('Preferences').last)).pop();
    await tester.pumpAndSettle();
    await expectSurface(
        app_style.AppPalette.lightModeDarkGrey, 'profile-return');
    expect(router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.byType(OneTouchBottomNavigationBar), findsOneWidget);
    expect(
      tester
          .widget<OneTouchBottomNavigationBar>(
            find.byType(OneTouchBottomNavigationBar),
          )
          .currentIndex,
      2,
    );
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      appThemeController.value = mode;
      router.go('/profile/activity');
      await tester.pumpAndSettle();
      final dark = mode == ThemeMode.dark;
      final activityColor =
          dark ? app_style.AppPalette.black : app_style.AppPalette.lightGreyBox;
      final postColor = dark
          ? app_style.AppPalette.black
          : app_style.AppPalette.lightModeDarkGrey;
      await expectSurface(activityColor, 'activity-${mode.name}');
      await tester.tap(find.text('My post 42'));
      await tester.pumpAndSettle();
      expect(find.byType(PostDetailScreen), findsOneWidget);
      await expectSurface(postColor, 'post-${mode.name}');
      await tester.drag(
          find.byType(CustomScrollView).last, const Offset(0, -250));
      await tester.pumpAndSettle();
      await expectSurface(postColor, 'post-scrolled-${mode.name}');
      Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
      await tester.pumpAndSettle();
      await expectSurface(activityColor, 'activity-return-${mode.name}');
    }
    appThemeController.value = ThemeMode.light;
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (final path in [
      '/profile/edit',
      '/profile/notification',
      '/profile/notification/team/Test',
      '/profile/notification/player/Test',
      '/profile/preference',
      '/profile/contact',
      '/profile/about',
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, path);
      expect(find.byType(OneTouchBottomNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (path == '/profile/preference') {
        await tester.tap(find.text('English'));
        await tester.pumpAndSettle();
        expect(find.byType(OneTouchBottomNavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new).last);
        await tester.pumpAndSettle();
      } else if (path == '/profile/about') {
        await tester.tap(find.text('Terms of Service'));
        await tester.pumpAndSettle();
        expect(find.byType(OneTouchBottomNavigationBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('about-detail-back')));
        await tester.pumpAndSettle();
      }
    }
    await tab(0);
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(
      requests.where((request) => request.method != 'GET').map(
            (request) => request.url.path,
          ),
      everyElement('/v1/users/me/points/initialize'),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
