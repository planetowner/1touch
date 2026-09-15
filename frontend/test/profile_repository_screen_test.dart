import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Profile.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/profile/current_user_repository.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/models/current_user_profile.dart';
import 'package:onetouch/models/team.dart';

void main() {
  testWidgets('loads current-user identity through the repository',
      (tester) async {
    await _setScreenSize(tester, const Size(320, 568));
    final repository = _ControlledCurrentUserRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Profile(
          repository: repository,
          followingTeamsRepository: _StaticFollowingTeamsRepository(),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.calls, hasLength(1));

    repository.calls.single.complete(_profile());
    await tester.pump();

    expect(find.text('Planet Owner'), findsOneWidget);
    expect(find.text('owner@example.com'), findsOneWidget);
    expect(find.text('API Barcelona'), findsOneWidget);
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

  testWidgets('opens the selected following team card', (tester) async {
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, __) => Profile(
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

    await tester.tap(find.byKey(const ValueKey('profile-following-team-83')));
    await tester.pumpAndSettle();

    expect(find.text('Team 83'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setScreenSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

CurrentUserProfile _profile({String? email = 'owner@example.com'}) {
  return CurrentUserProfile(
    userId: 1,
    username: 'planetowner',
    firstName: 'Planet',
    lastName: 'Owner',
    email: email,
    avatarUri: null,
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
