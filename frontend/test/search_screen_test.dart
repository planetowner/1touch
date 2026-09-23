import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Search.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/search/search_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/models/team.dart';

class _Context implements TeamCompetitionContextResolver {
  @override
  TeamCompetitionContext? resolve(int id) => TeamCompetitionContext(
      teamId: id,
      seasonId: 28083,
      competitionId: 8,
      competitionName: 'Premier League');
}

class _Preferences implements UserPreferencesRepository {
  @override
  Future<UserTeamPreferences?> load() async => null;
  @override
  Future<void> save(UserTeamPreferences value) async {}
}

class _Search implements SearchRepository {
  final calls = <String>[];
  final pending = <Completer<SearchResults>>[];
  @override
  Future<SearchResults> search(String query) {
    calls.add(query);
    final request = Completer<SearchResults>();
    pending.add(request);
    return request.future;
  }
}

const _team = Team(teamId: 8, name: 'Example United');
const _results = SearchResults(
    players: [(id: 123, name: '선수 Example', image: null)], teams: [_team]);

Future<void> _pump(WidgetTester tester, _Search repository,
    {bool dark = false, GoRouter? router}) async {
  final preferences = CurrentUserPreferences(
      repository: _Preferences(),
      teamRepository: MockTeamRepository(teams: [_team]),
      fallback:
          const UserTeamPreferences(favoriteTeamId: 8, followedTeamIds: [8]));
  final screen = Search(
      repository: repository,
      competitionContextResolver: _Context(),
      preferences: preferences);
  final routing = router ??
      GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => screen),
        GoRoute(
            path: '/players/:id',
            builder: (_, state) =>
                Text('Player ID ${state.pathParameters['id']}')),
      ]);
  addTearDown(routing.dispose);
  await tester.pumpWidget(MaterialApp.router(
      theme: dark ? app_style.darktheme : app_style.whitetheme,
      routerConfig: routing));
  await tester.pump();
}

Future<void> _query(WidgetTester tester, String text) async {
  await tester.enterText(
      find.byKey(const ValueKey('global-search-field')), text);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets(
      'empty input shows a prompt without fabricated recents or a request',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    expect(find.byKey(const ValueKey('search-prompt')), findsOneWidget);
    expect(find.text('RECENTS'), findsNothing);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'API results retain card styling, category tabs and numeric player navigation',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo, dark: true);
    await _query(tester, 'Example');
    repo.pending.single.complete(_results);
    await tester.pumpAndSettle();
    final card = tester
        .widget<Container>(find.byKey(const ValueKey('search-player-123')));
    expect((card.decoration as BoxDecoration).color,
        app_style.AppPalette.darkGrey);
    expect(find.byKey(const ValueKey('search-team-8')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('search-tab-players')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-team-8')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('search-player-123')));
    await tester.pumpAndSettle();
    expect(find.text('Player ID 123'), findsOneWidget);
  });
  testWidgets(
      'older responses cannot replace a newer query or restore cleared results',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    await _query(tester, 'old');
    await _query(tester, 'new');
    repo.pending[1].complete(const SearchResults());
    await tester.pumpAndSettle();
    repo.pending[0].complete(_results);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-empty-results')), findsOneWidget);
    await _query(tester, 'pending');
    await tester.tap(find.byTooltip('Clear search'));
    repo.pending[2].complete(_results);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-prompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-player-123')), findsNothing);
  });
  testWidgets('a failed search offers a retry for the same query',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    await _query(tester, 'retry');
    repo.pending.single.completeError(StateError('Unavailable'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-load-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    repo.pending.last.complete(_results);
    await tester.pumpAndSettle();
    expect(repo.calls, ['retry', 'retry']);
    expect(find.byKey(const ValueKey('search-player-123')), findsOneWidget);
  });
}
