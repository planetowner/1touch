import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/SessionScreen.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/user_preferences.dart';

void main() {
  late Map<String, dynamic> account;
  var fail = false;
  final requests = <http.Request>[];
  final catalog =
      jsonDecode(File('test/fixtures/api_catalog.json').readAsStringSync())
          as Map<String, dynamic>;
  setUpAll(() {
    http.runWithClient(
        () => apiClient.baseUri,
        () => MockClient((request) async {
              requests.add(request);
              Object body;
              switch (request.url.path) {
                case '/v1/catalog':
                  body = catalog;
                case '/v1/users/me':
                  if (fail) return http.Response('{}', 500);
                  body = account;
                case '/v1/users/me/profile':
                  account
                      .addAll(jsonDecode(request.body) as Map<String, dynamic>);
                  body = account;
                case '/v1/users/me/following/teams':
                  body = [catalog['teams'][0]];
                case '/v1/users/me/following/players':
                  body = {'items': []};
                default:
                  throw StateError('Unexpected request ${request.url}');
              }
              return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
            }));
  });
  setUp(() {
    fail = false;
    requests.clear();
    authSession
        .establish('test-session-${DateTime.now().microsecondsSinceEpoch}');
    account = {
      'user_id': 1,
      'username': 'example',
      'first_name': 'First',
      'last_name': 'Last',
      'email': null,
      'avatar_url': null,
      'favorite_team_id': 8,
      'created_at': '2026-09-22T00:00:00Z',
      'onboarding_complete': true
    };
  });
  Future<void> pump(WidgetTester tester) async {
    final router = GoRouter(initialLocation: '/session', routes: [
      GoRoute(path: '/session', builder: (_, __) => const SessionScreen()),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Ready Home'))),
      GoRoute(
          path: '/onboarding/welcome',
          builder: (_, __) => const Scaffold(body: Text('Select Teams Next'))),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Sign In'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('prepares real catalog and saved preferences before opening Home',
      (tester) async {
    await pump(tester);
    expect(find.text('Ready Home'), findsOneWidget);
    expect(currentUserPreferences.favoriteTeamId.value, 8);
    expect(currentUserPreferences.followedTeamIds.value, [8]);
    expect(isAppSessionReady, isTrue);
    expect(
        requests.every((r) =>
            r.headers['Authorization'] == 'Bearer ${authSession.accessToken}'),
        isTrue);
  });
  testWidgets(
      'incomplete social profile uses the same profile update endpoint before team selection',
      (tester) async {
    account.addAll({
      'username': null,
      'first_name': null,
      'last_name': null,
      'favorite_team_id': null,
      'onboarding_complete': false
    });
    await pump(tester);
    expect(find.text('Complete your profile'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('profile-first-name-field')), 'First');
    await tester.enterText(
        find.byKey(const ValueKey('profile-last-name-field')), 'Last');
    await tester.enterText(
        find.byKey(const ValueKey('profile-username-field')), 'chosen');
    await tester.tap(find.text('Save profile'));
    await tester.pumpAndSettle();
    expect(find.text('Select Teams Next'), findsOneWidget);
    final update = requests.singleWhere((r) => r.method == 'PUT');
    expect(jsonDecode(update.body),
        {'username': 'chosen', 'first_name': 'First', 'last_name': 'Last'});
    expect(isAppSessionReady, isFalse);
  });
  testWidgets('a failed account load stays on a retry screen', (tester) async {
    fail = true;
    await pump(tester);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Ready Home'), findsNothing);
    expect(isAppSessionReady, isFalse);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Ready Home'), findsOneWidget);
  });
}
