import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'support/api_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/session_screen.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/notification_navigation.dart';
import 'package:onetouch/core/community_link_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/home_data.dart';

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
              switch (relativeApiPath(request.url)) {
                case 'catalog':
                  body = catalog;
                case 'users/me':
                  if (fail) return http.Response('{}', 500);
                  body = account;
                case 'users/me/points/initialize':
                  body = {'balance': 0, 'initialized': true};
                case 'users/me/profile':
                  account
                      .addAll(jsonDecode(request.body) as Map<String, dynamic>);
                  body = account;
                case 'users/me/following/teams':
                  body = [catalog['teams'][0]];
                case 'users/me/following/players':
                  body = {'items': []};
                default:
                  throw StateError('Unexpected request ${request.url}');
              }
              return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
            }));
  });
  setUp(() async {
    await clearAuthenticatedLocalCache();
    notificationNavigation.clear();
    communityLinkNavigation.clear();
    fail = false;
    requests.clear();
    authSession
        .establish('test-session-${DateTime.now().microsecondsSinceEpoch}');
    account = {
      'user_id': 1,
      'username': null,
      'display_name': 'Example',
      'email': null,
      'avatar_url': null,
      'favorite_team_id': 8,
      'created_at': '2026-09-22T00:00:00Z',
      'onboarding_complete': true
    };
  });
  Future<void> pump(WidgetTester tester,
      {Locale locale = const Locale('en'),
      HomeSnapshotRepository? homeRepository,
      bool settle = true}) async {
    final router = GoRouter(initialLocation: '/session', routes: [
      GoRoute(
          path: '/session',
          builder: (_, __) => SessionScreen(
              checkNicknameAvailability: (_) async => true,
              logout: () async => authSession.clear(),
              homeRepository: homeRepository ??
                  (_PendingHomeSnapshotRepository()..complete()))),
      GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: Text('Ready Home'))),
      GoRoute(
          path: '/match/:id',
          builder: (_, state) => Scaffold(
                body: Text(
                    'Match ${state.pathParameters['id']} ${state.uri.queryParameters['status']}'),
              )),
      GoRoute(
          path: '/community/:postId',
          builder: (_, state) => Scaffold(
                body: Text('Post ${state.pathParameters['postId']}'),
              )),
      GoRoute(
          path: '/onboarding/welcome',
          builder: (_, __) => const Scaffold(body: Text('Select Teams Next'))),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('Sign In'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      routerConfig: router,
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
    ));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  testWidgets('restores the local Home snapshot before entering Home',
      (tester) async {
    final repository = _PendingHomeSnapshotRepository();
    await pump(tester, homeRepository: repository, settle: false);
    for (var attempt = 0;
        attempt < 30 && repository.teamId == null;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(repository.teamId, 8);
    final now = DateTime.now();
    expect(repository.month, DateTime(now.year, now.month));
    expect(find.text('Ready Home'), findsNothing);
    repository.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ready Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
  testWidgets('a social member without a nickname must complete the profile',
      (tester) async {
    account['display_name'] = null;
    await pump(tester);
    expect(find.text('Ready Home'), findsNothing);
    expect(find.text('Pick a nickname'), findsOneWidget);
  });

  testWidgets('opens a queued notification after session bootstrap',
      (tester) async {
    notificationNavigation.queue(
      '/match/42?status=past',
      sessionToken: authSession.accessToken!,
    );

    await pump(tester);

    expect(find.text('Match 42 past'), findsOneWidget);
    expect(notificationNavigation.take(sessionToken: authSession.accessToken!),
        isNull);
  });

  testWidgets('does not open a notification from another session',
      (tester) async {
    notificationNavigation.queue(
      '/match/42?status=past',
      sessionToken: 'previous-account-token',
    );

    await pump(tester);

    expect(find.text('Ready Home'), findsOneWidget);
  });
  testWidgets('opens a shared post after session bootstrap', (tester) async {
    communityLinkNavigation.queue('/community/12');

    await pump(tester);

    expect(find.text('Post 12'), findsOneWidget);
    expect(communityLinkNavigation.take(sessionToken: authSession.accessToken!),
        isNull);
  });

  testWidgets('does not open another account shared post', (tester) async {
    communityLinkNavigation.queue('/community/12', sessionToken: 'other');

    await pump(tester);

    expect(find.text('Ready Home'), findsOneWidget);
  });
  for (final locale in appSupportedLocales) {
    testWidgets('social profile saves only nickname with $locale',
        (tester) async {
      account.addAll({
        'username': null,
        'display_name': null,
        'favorite_team_id': null,
        'onboarding_complete': false
      });
      await pump(tester, locale: locale);
      expect(find.text(translateMessage(locale, 'Pick a nickname')),
          findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('social-nickname-field')), 'Supporter');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text(translateMessage(locale, 'CONTINUE')));
      await tester.pumpAndSettle();
      expect(find.text('Select Teams Next'), findsOneWidget);
      final update = requests.singleWhere((r) => r.method == 'PUT');
      expect(jsonDecode(update.body), {
        'display_name': 'Supporter',
      });
      expect(account['username'], isNull);
      expect(isAppSessionReady, isFalse);
    });
  }
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

class _PendingHomeSnapshotRepository implements HomeSnapshotRepository {
  final _restored = Completer<HomeSnapshot?>();
  int? teamId;
  DateTime? month;

  @override
  Future<HomeSnapshot?> restoreFor({
    required int teamId,
    required DateTime month,
  }) {
    this.teamId = teamId;
    this.month = month;
    return _restored.future;
  }

  void complete() => _restored.complete(null);

  @override
  HomeSnapshot? snapshotFor({required int teamId, required DateTime month}) =>
      null;

  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) =>
      throw UnimplementedError();

  @override
  void clearSnapshots() {}
}
