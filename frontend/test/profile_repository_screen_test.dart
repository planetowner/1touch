import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/comm_pages/profile_activity_screen.dart';
import 'package:onetouch/comm_pages/Profile_settings/InfoEdit.dart';
import 'package:onetouch/comm_pages/Profile_settings/TeamEdit.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/profile_activity_counts.dart';
import 'package:onetouch/models/team.dart';
import 'support/player_directory_fixture.dart';
import 'support/stub_profile_activity_repository.dart';

void main() {
  setUpAppCatalog();
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('activity counts load, retry and fit at $size', (tester) async {
      await _setScreenSize(tester, size);
      final activity = _ControlledActivityRepository();
      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Profile(
          repository: _StaticCurrentUserRepository(),
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
          activityRepository: activity,
        ),
      ));
      await tester.pump();
      expect(find.text('@불광동호날두'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-stat-posts-loading')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('profile-stat-comments-loading')),
          findsOneWidget);
      _expectStat('points', '0');
      _expectStat('posts', '0', absent: true);
      _expectStat('comments', '0', absent: true);

      activity.calls.single.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      _expectStat('posts', '—');
      _expectStat('comments', '—');
      expect(find.text('게시글·댓글 수를 불러오지 못했어요.'), findsOneWidget);
      final retry = find.byKey(const ValueKey('profile-activity-counts-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pump();
      expect(activity.calls, hasLength(2));
      activity.calls.last
          .complete(const ProfileActivityCounts(postCount: 0, commentCount: 0));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('profile-stat-card')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      _expectStat('posts', '0');
      _expectStat('comments', '0');
      expect(retry, findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('large activity counts remain inside each box at $size',
        (tester) async {
      await _setScreenSize(tester, size);
      final activity = _ControlledActivityRepository();
      await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: Profile(
          repository: _StaticCurrentUserRepository(),
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
          activityRepository: activity,
        ),
      ));
      activity.calls.single.complete(const ProfileActivityCounts(
          postCount: 1234567890123, commentCount: 9876543210123));
      await tester.pumpAndSettle();
      for (final entry in {
        'posts': '1234567890123',
        'comments': '9876543210123',
      }.entries) {
        _expectStat(entry.key, entry.value);
        final box =
            tester.getRect(find.byKey(ValueKey('profile-stat-${entry.key}')));
        final number = tester.getRect(find.text(entry.value));
        expect(number.left, greaterThanOrEqualTo(box.left));
        expect(number.right, lessThanOrEqualTo(box.right + 0.1));
      }
      _expectStat('points', '0');
      expect(tester.takeException(), isNull);
    });
  }

  for (final tab in ['posts', 'comments']) {
    testWidgets('returning from $tab reloads activity counts', (tester) async {
      final activity = _ControlledActivityRepository();
      final router = GoRouter(initialLocation: '/profile', routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
            activityRepository: activity,
          ),
        ),
        GoRoute(
          path: '/profile/activity',
          builder: (_, state) => ProfileActivityScreen(
            repository: activity,
            profile: state.extra as CurrentUserProfile?,
            initialTab: state.uri.queryParameters['tab'] == 'comments'
                ? ProfileActivityTab.comments
                : ProfileActivityTab.posts,
          ),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      activity.calls.single.complete(
          const ProfileActivityCounts(postCount: 122, commentCount: 124));
      await tester.pumpAndSettle();
      _expectStat('posts', '122');
      _expectStat('comments', '124');
      final stat = find.byKey(ValueKey('profile-stat-$tab'));
      await tester.ensureVisible(stat);
      await tester.tap(stat);
      await tester.pumpAndSettle();
      expect(
          find.byKey(ValueKey('profile-activity-empty-$tab')), findsOneWidget);
      router.pop();
      await tester.pump();
      expect(activity.calls, hasLength(2));
      activity.calls.last.complete(
          const ProfileActivityCounts(postCount: 121, commentCount: 123));
      await tester.pumpAndSettle();
      _expectStat('posts', '121');
      _expectStat('comments', '123');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('team changes refresh counts and discard an older pending result',
      (tester) async {
    final activity = _ControlledActivityRepository();
    await tester.pumpWidget(MaterialApp(
      home: Profile(
        repository: _StaticCurrentUserRepository(),
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
        activityRepository: activity,
      ),
    ));
    await tester.pump();
    final editIcon = find.byIcon(Icons.border_color).first;
    await tester.ensureVisible(editIcon);
    await tester.tap(editIcon);
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(tester.element(find.byType(EditFollowingTeamsSheet))).pop(
      const FollowingTeamsEditResult(
        teams: [Team(teamId: 19, name: 'API Arsenal')],
        favoriteTeamId: 19,
      ),
    );
    await tester.pump();
    expect(activity.calls, hasLength(2));
    activity.calls.last
        .complete(const ProfileActivityCounts(postCount: 3, commentCount: 5));
    await tester.pumpAndSettle();
    activity.calls.first.complete(
        const ProfileActivityCounts(postCount: 122, commentCount: 124));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-stat-card')),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    _expectStat('posts', '3');
    _expectStat('comments', '5');
    expect(find.text('API Arsenal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity requests can finish after leaving the profile',
      (tester) async {
    final activity = _ControlledActivityRepository();
    await tester.pumpWidget(MaterialApp(
      home: Profile(
        repository: _StaticCurrentUserRepository(),
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
        activityRepository: activity,
      ),
    ));
    await tester.pumpWidget(const SizedBox());
    activity.calls.single.completeError(StateError('offline'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'profile nickname and personal info names stay distinct by locale',
      (tester) async {
    for (final page in [
      Profile(
        activityRepository: const StubProfileActivityRepository(),
        repository: _StaticCurrentUserRepository(),
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
      ),
      EditProfileScreen(profile: _profile()),
    ]) {
      for (final locale in appSupportedLocales) {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          home: page,
        ));
        await tester.pumpAndSettle();
        final expected =
            locale.languageCode == 'en' ? 'Planet Owner' : 'OwnerPlanet';
        if (page is EditProfileScreen) {
          final field = tester.widget<TextField>(
            find.byKey(const ValueKey('profile-real-name-field')),
          );
          expect(field.controller!.text, expected);
        } else {
          expect(find.text('@불광동호날두'), findsOneWidget);
          expect(find.text(expected), findsNothing);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('loads current-user identity through the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledCurrentUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Profile(
          activityRepository: const StubProfileActivityRepository(),
          repository: repository,
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
        ),
      ),
    );

    expect(find.byType(FootballLoadingIndicator), findsOneWidget);
    expect(repository.calls, hasLength(1));

    repository.calls.single.complete(_profile());
    await tester.pump();

    expect(find.text('@불광동호날두'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('API Barcelona'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'existing member can open the nickname editor before choosing one',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final repository = _ControlledCurrentUserRepository();
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: Profile(
        activityRepository: const StubProfileActivityRepository(),
        repository: repository,
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
      ),
    ));
    repository.calls.single.complete(_profile(displayName: null));
    await tester.pump();
    expect(find.text('@planetowner'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      home: EditProfileScreen(profile: _profile(displayName: null)),
    ));
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('profile-display-name-field')),
    );
    expect(field.controller!.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries a failed load and falls back to the username',
      (tester) async {
    await _setScreenSize(tester, const Size(430, 932));
    final repository = _ControlledCurrentUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Profile(
          activityRepository: const StubProfileActivityRepository(),
          repository: repository,
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
        ),
      ),
    );

    repository.calls.single.completeError(StateError('offline'));
    await tester.pump();

    expect(find.text('Unable to load Profile.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-retry-button')));
    await tester.pump();
    expect(repository.calls, hasLength(2));

    repository.calls.last.complete(_profile(email: null));
    await tester.pump();

    expect(find.text('@planetowner'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loads a private avatar with authenticated request headers',
      (tester) async {
    final repository = _ControlledCurrentUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Profile(
          activityRepository: const StubProfileActivityRepository(),
          repository: repository,
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
          avatarRequestHeaders: const {
            'Authorization': 'Bearer test-session',
          },
        ),
      ),
    );

    repository.calls.single.complete(
      _profile(avatarUri: Uri.parse('https://api.example/users/1/avatar')),
    );
    await tester.pump();

    final image = tester.widget<Image>(
      find.byKey(const ValueKey('profile-avatar-network')),
    );
    final provider = image.image as NetworkImage;
    expect(provider.url, 'https://api.example/users/1/avatar');
    expect(
      provider.headers,
      containsPair('Authorization', 'Bearer test-session'),
    );
  });

  testWidgets('opens the following teams editor from the profile icon',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    await tester.pumpWidget(MaterialApp(
      theme: app_style.whitetheme,
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Profile(
        activityRepository: const StubProfileActivityRepository(),
        repository: _StaticCurrentUserRepository(),
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
      ),
    ));
    await tester.pumpAndSettle();
    final editIcon = find.byIcon(Icons.border_color).first;
    await tester.ensureVisible(editIcon);
    await tester.pumpAndSettle();
    await tester.tap(editIcon);
    await tester.pumpAndSettle();

    final sheet = find.byKey(const ValueKey('profile-team-edit-sheet'));
    expect(sheet, findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('API Barcelona')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean following-team cards fit the taller typography',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    appLocaleController.value = const Locale('ko');
    addTearDown(() => appLocaleController.value = const Locale('en'));

    await tester.pumpWidget(MaterialApp(
      theme: app_style.lightThemeForLocale(const Locale('ko')),
      locale: const Locale('ko'),
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      home: Profile(
        activityRepository: const StubProfileActivityRepository(),
        repository: _StaticCurrentUserRepository(),
        followingTeamsRepository: _StaticFollowingTeamsRepository(),
      ),
    ));
    await tester.pumpAndSettle();

    final teamCard = find.byKey(
      const ValueKey('profile-following-team-83'),
    );
    expect(teamCard, findsOneWidget);
    expect(tester.getSize(teamCard).height, 168);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the selected following team card', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
            activityRepository: const StubProfileActivityRepository(),
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
          ),
        ),
        GoRoute(
          path: '/team/:id',
          builder: (_, state) => Scaffold(
            body: Text('Team ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: app_style.whitetheme,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();

    final followedTeam =
        find.byKey(const ValueKey('profile-following-team-83'));
    await tester.ensureVisible(followedTeam);
    await tester.pumpAndSettle();
    await tester.tap(followedTeam);
    await tester.pumpAndSettle();

    expect(find.text('Team 83'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens a followed player from the root profile page',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final followingController = PlayerFollowingController(
      repository: FakeFollowingPlayersRepository(),
    );
    addTearDown(followingController.dispose);
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => Scaffold(body: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/players',
                builder: (_, __) => const Scaffold(body: Text('Players')),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => Scaffold(
                      body: Text('Player ${state.pathParameters['id']}'),
                    ),
                  ),
                ],
              ),
            ]),
          ],
        ),
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
            activityRepository: const StubProfileActivityRepository(),
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
            followingController: followingController,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(
      theme: app_style.whitetheme,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();
    final followedPlayer = find.byKey(const ValueKey('favorite-player-1'));
    await tester.ensureVisible(followedPlayer);
    await tester.pumpAndSettle();
    await tester.tap(followedPlayer);
    await tester.pumpAndSettle();

    expect(find.text('Player 1'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/players/1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('all three profile stats open my activity with the right tab',
      (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
            activityRepository: const StubProfileActivityRepository(),
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
          ),
        ),
        GoRoute(
          path: '/profile/activity',
          builder: (_, state) => ProfileActivityScreen(
            repository: const StubProfileActivityRepository(),
            profile: state.extra as CurrentUserProfile?,
            initialTab: state.uri.queryParameters['tab'] == 'comments'
                ? ProfileActivityTab.comments
                : ProfileActivityTab.posts,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: app_style.whitetheme,
      routerConfig: router,
    ));

    for (final stat in ['points', 'posts', 'comments']) {
      router.go('/profile');
      await tester.pumpAndSettle();
      final statFinder = find.byKey(ValueKey('profile-stat-$stat'));
      await tester.ensureVisible(statFinder);
      await tester.pumpAndSettle();
      await tester.tap(statFinder);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-activity-screen')),
          findsOneWidget);
      expect(
        find.byKey(ValueKey(
          'profile-activity-empty-${stat == 'comments' ? 'comments' : 'posts'}',
        )),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('profile setting rows open their routes', (tester) async {
    await _setScreenSize(tester, const Size(393, 852));
    final destinations = <String, String>{
      'profile-setting-personal-info': '/profile/edit',
      'profile-setting-notification': '/profile/notification',
      'profile-setting-preferences': '/profile/preference',
      'profile-setting-contact': '/profile/contact',
      'profile-setting-about': '/profile/about',
    };
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
            activityRepository: const StubProfileActivityRepository(),
            repository: _StaticCurrentUserRepository(),
            followingTeamsRepository: _StaticFollowingTeamsRepository(),
          ),
        ),
        for (final route in destinations.values)
          GoRoute(
            path: route,
            builder: (_, __) => Scaffold(body: Text('route:$route')),
          ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        theme: app_style.whitetheme,
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -2400),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const ValueKey('profile-setting-dark-theme')),
          )
          .onTap,
      isNotNull,
    );

    for (final entry in destinations.entries) {
      final item = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      await tester.tap(item);
      await tester.pumpAndSettle();

      expect(find.text('route:${entry.value}'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _expectStat(String stat, String value, {bool absent = false}) {
  expect(
    find.descendant(
      of: find.byKey(ValueKey('profile-stat-$stat')),
      matching: find.text(value),
    ),
    absent ? findsNothing : findsOneWidget,
  );
}

class _ControlledActivityRepository extends StubProfileActivityRepository {
  final List<Completer<ProfileActivityCounts>> calls = [];

  @override
  Future<ProfileActivityCounts> loadCounts() {
    final completer = Completer<ProfileActivityCounts>();
    calls.add(completer);
    return completer.future;
  }
}

CurrentUserProfile _profile({
  String? email = 'owner@example.com',
  String? displayName = '불광동호날두',
  Uri? avatarUri,
}) {
  return CurrentUserProfile(
    userId: 1,
    username: 'planetowner',
    displayName: displayName,
    firstName: 'Planet',
    lastName: 'Owner',
    email: email,
    avatarUri: avatarUri,
    favoriteTeamId: 83,
    createdAt: DateTime.utc(2026),
  );
}

class _ControlledCurrentUserRepository implements CurrentUserRepository {
  final List<Completer<CurrentUserProfile>> calls = [];

  @override
  Future<CurrentUserProfile> load() {
    final completer = Completer<CurrentUserProfile>();
    calls.add(completer);
    return completer.future;
  }
}

class _StaticCurrentUserRepository implements CurrentUserRepository {
  @override
  Future<CurrentUserProfile> load() async => _profile();
}

class _StaticFollowingTeamsRepository implements FollowingTeamsRepository {
  final ValueNotifier<List<Team>> _cache = ValueNotifier(const []);

  @override
  ValueListenable<List<Team>> get cachedTeams => _cache;

  @override
  Future<List<Team>> load() async {
    const teams = [Team(teamId: 83, name: 'API Barcelona')];
    _cache.value = teams;
    return teams;
  }

  @override
  Future<List<Team>> replaceFollowing({
    required Iterable<int> teamIds,
    required int favoriteTeamId,
  }) =>
      throw UnimplementedError();
}
