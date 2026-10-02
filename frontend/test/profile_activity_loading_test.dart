import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/profile/api/api_profile_activity_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/screens/CommunityScreen_utils/post_screen.dart';

import 'support/app_catalog.dart';
import 'support/profile_activity_fixture.dart';

void main() {
  setUpAppCatalog();

  for (final tab in ProfileActivityTab.values) {
    testWidgets('${tab.name} loads the initial tab and switches endpoints',
        (tester) async {
      final pending = Completer<http.Response>();
      final paths = <String>[];
      await _show(tester, tab, (request) async {
        paths.add(request.url.path);
        if (paths.length == 1) return pending.future;
        final other = tab == ProfileActivityTab.posts
            ? ProfileActivityTab.comments
            : ProfileActivityTab.posts;
        return _page(request, [_item(other, 99)]);
      });
      expect(paths, ['/v1/users/me/${tab.name}']);
      expect(find.byKey(ValueKey('profile-activity-loading-${tab.name}')),
          findsOneWidget);
      expect(find.byKey(ValueKey('profile-activity-empty-${tab.name}')),
          findsNothing);
      pending.complete(
          http.Response(jsonEncode(activityPageJson([_item(tab, 42)])), 200));
      await tester.pumpAndSettle();
      expect(find.text(_label(tab, 42)), findsOneWidget);

      final other = tab == ProfileActivityTab.posts
          ? ProfileActivityTab.comments
          : ProfileActivityTab.posts;
      await tester
          .tap(find.byKey(ValueKey('profile-activity-tab-${other.name}')));
      await tester.pumpAndSettle();
      expect(paths.last, '/v1/users/me/${other.name}');
      expect(find.text(_label(other, 99)), findsOneWidget);
      expect(find.text(_label(tab, 42)), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${tab.name} request failures show retry instead of an empty state',
        (tester) async {
      var attempts = 0;
      await _show(tester, tab, (request) async {
        if (++attempts == 1) return http.Response('{}', 500);
        return _page(request, [_item(tab, 42)]);
      });
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('profile-activity-empty-${tab.name}')),
          findsNothing);
      await tester
          .tap(find.byKey(ValueKey('profile-activity-retry-${tab.name}')));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text(_label(tab, 42)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${tab.name} appends pages and retries a failed page at the same offset',
        (tester) async {
      final offsets = <int>[];
      await _show(tester, tab, (request) async {
        final offset = int.parse(request.url.queryParameters['offset']!);
        offsets.add(offset);
        if (offset == 0) {
          return _page(request, List.generate(50, (i) => _item(tab, i + 1000)));
        }
        if (offsets.length == 2) return http.Response('{}', 500);
        return _page(request, [_item(tab, 1050)]);
      });
      await tester.pumpAndSettle();
      for (var i = 0; i < 40 && offsets.length < 2; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -800));
        await tester.pumpAndSettle();
      }
      expect(offsets, [0, 50]);
      await tester
          .tap(find.byKey(ValueKey('profile-activity-retry-${tab.name}')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text(_label(tab, 1050)), 400,
          scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(find.text(_label(tab, 1050)), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(offsets, [0, 50, 50]);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${tab.name} refresh replaces the previous result from offset zero',
        (tester) async {
      final offsets = <String>[];
      await _show(tester, tab, (request) async {
        offsets.add(request.url.queryParameters['offset']!);
        return _page(request, [_item(tab, offsets.length == 1 ? 42 : 99)]);
      });
      await tester.pumpAndSettle();
      unawaited(tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show());
      await tester.pumpAndSettle();
      expect(offsets, ['0', '0']);
      expect(find.text(_label(tab, 42)), findsNothing);
      expect(find.text(_label(tab, 99)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '${tab.name} opens its original post and reloads after returning',
        (tester) async {
      var attempts = 0;
      await _show(tester, tab, (request) async {
        attempts++;
        return _page(request, [_item(tab, attempts == 1 ? 42 : 99)]);
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text(_label(tab, 42)));
      await tester.pumpAndSettle();
      final detail =
          tester.widget<PostDetailScreen>(find.byType(PostDetailScreen));
      expect(detail.post.postId, 42);
      Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text(_label(tab, 99)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'a late response from the previous tab does not replace the selected tab',
      (tester) async {
    final pending = Completer<http.Response>();
    await _show(tester, ProfileActivityTab.posts, (request) async {
      if (request.url.path.endsWith('/posts')) return pending.future;
      return _page(request, [activityCommentJson(id: 99)]);
    });
    await tester
        .tap(find.byKey(const ValueKey('profile-activity-tab-comments')));
    await tester.pumpAndSettle();
    pending.complete(
        http.Response(jsonEncode(activityPageJson([activityPostJson()])), 200));
    await tester.pumpAndSettle();
    expect(find.text('My comment 99'), findsOneWidget);
    expect(find.text('Post body 42'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _show(WidgetTester tester, ProfileActivityTab tab,
    MockClientHandler handler) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final api = ApiClient(
    client: MockClient(handler),
    baseUri: Uri.parse('https://api.test/v1/'),
    requestHeaders: () => const {'Authorization': 'Bearer session-token'},
  );
  addTearDown(api.close);
  await tester.pumpWidget(MaterialApp(
    theme: whitetheme,
    home: ProfileActivityScreen(
      profile: CurrentUserProfile(
        userId: 1,
        username: 'owner',
        displayName: 'Owner',
        email: null,
        avatarUri: null,
        favoriteTeamId: 83,
        createdAt: DateTime.utc(2026),
      ),
      initialTab: tab,
      repository: ApiProfileActivityRepository(api: api),
    ),
  ));
  await tester.pump();
}

Map<String, dynamic> _item(ProfileActivityTab tab, int id) =>
    tab == ProfileActivityTab.posts
        ? activityPostJson(id: id)
        : activityCommentJson(id: id, postId: id);

String _label(ProfileActivityTab tab, int id) =>
    tab == ProfileActivityTab.posts ? 'My post $id' : 'My comment $id';

http.Response _page(http.Request request, List<Map<String, dynamic>> items) =>
    http.Response(
        jsonEncode(activityPageJson(
          items,
          limit: int.parse(request.url.queryParameters['limit']!),
          offset: int.parse(request.url.queryParameters['offset']!),
        )),
        200);
