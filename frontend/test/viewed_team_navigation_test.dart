import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/main.dart';
import 'package:onetouch/features/community/community_access.dart';
import 'package:onetouch/screens/community_screen.dart';
import 'package:onetouch/screens/home_screen.dart';
import 'package:onetouch/screens/team_screen.dart';

void main() {
  testWidgets('Home selection reaches retained Team and Community tabs',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    await tester.pumpWidget(const MyApp());
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
    expect(tester.widget<TeamScreen>(find.byType(TeamScreen)).teamId, 8);
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
      expect(router.routeInformationProvider.value.uri.path, '/team/$id');
      expect(tester.widget<TeamScreen>(find.byType(TeamScreen)).teamId, id);
      await tab(3);
      expect(tester.widget<Community>(find.byType(Community)).teamId, id);
      expect(find.byType(CommunityReadOnlyNotice),
          id == 8 ? findsNothing : findsOneWidget);
      expect(find.byType(FloatingActionButton),
          id == 8 ? findsOneWidget : findsNothing);
      expect(tester.state(find.byType(Community)), same(communityState));
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
