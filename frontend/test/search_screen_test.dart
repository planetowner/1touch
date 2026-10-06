import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/Search.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/search/search_repository.dart';
import 'package:onetouch/data/teams/mock/mock_team_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/l10n/app_localizations.dart';

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
    {bool dark = false,
    GoRouter? router,
    Locale locale = const Locale('en')}) async {
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
        GoRoute(
            path: '/match/:id',
            builder: (_, state) =>
                Text('Match ID ${state.pathParameters['id']}')),
      ]);
  addTearDown(routing.dispose);
  await tester.pumpWidget(MaterialApp.router(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
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
  for (final dark in [false, true]) {
    testWidgets(
        'upcoming search card follows the compact layout in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
      final previousCompetitions = footballCatalog.competitions.value;
      footballCatalog.competitions.value = const [
        Competition(competitionId: 564, name: 'La Liga'),
      ];
      addTearDown(
          () => footballCatalog.competitions.value = previousCompetitions);

      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(320, 568);

      final repo = _Search();
      await _pump(tester, repo, dark: dark);
      await _query(tester, 'Chelsea');
      repo.pending.single.complete(SearchResults(fixtures: [
        Fixture(
          fixtureId: 105,
          seasonId: 1,
          competitionId: 564,
          homeTeamId: 18,
          awayTeamId: 90,
          homeTeamName: 'Chelsea',
          awayTeamName: 'Athletic Club',
          homeTeamShortName: 'CHE',
          awayTeamShortName: 'ATH',
          competitionType: CompetitionType.league,
          status: FixtureStatus.upcoming,
          roundName: '8',
          startingAt: DateTime(2026, 10, 10, 16, 30).toIso8601String(),
        ),
        Fixture(
          fixtureId: 106,
          seasonId: 1,
          competitionId: 564,
          homeTeamId: 18,
          awayTeamId: 90,
          competitionType: CompetitionType.league,
          status: FixtureStatus.past,
          roundName: '7',
          startingAt: DateTime(2026, 10, 3, 16, 30).toIso8601String(),
          homeScore: 2,
          awayScore: 1,
        ),
      ]));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('search-event-105'));
      expect(tester.getSize(card).height, 96);
      expect(find.descendant(of: card, matching: find.text('CHE')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('ATH')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Sat, Oct 10')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('4:30 PM')),
          findsOneWidget);
      expect(
          find.descendant(of: card, matching: find.text('LA LIGA · Round 8')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('-')), findsNothing);
      final pastCard = find.byKey(const ValueKey('search-event-106'));
      expect(find.descendant(of: pastCard, matching: find.text('2')),
          findsOneWidget);
      expect(find.descendant(of: pastCard, matching: find.text('1')),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(430, 932);
      await tester.pumpAndSettle();
      expect(tester.getSize(card).height, 96);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Korean search fixtures use the shared match date format',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo, locale: const Locale('ko'));
    await _query(tester, 'Example');
    repo.pending.single.complete(SearchResults(fixtures: [
      Fixture(
          fixtureId: 100,
          seasonId: 1,
          competitionId: 564,
          homeTeamId: 83,
          awayTeamId: 90,
          competitionType: CompetitionType.league,
          status: FixtureStatus.upcoming,
          roundName: '8',
          startingAt: DateTime(2026, 10, 10, 16, 30).toIso8601String()),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('10월 10일 (토)'), findsOneWidget);
    expect(find.text('4:30 PM'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('postponed and cancelled search matches cannot open',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    await _query(tester, 'Nantes');
    repo.pending.single.complete(SearchResults(fixtures: [
      for (final (id, stateId, status) in [
        (101, 10, FixtureStatus.upcoming),
        (102, 12, FixtureStatus.unknown),
        (103, 1, FixtureStatus.upcoming),
      ])
        Fixture(
          fixtureId: id,
          seasonId: 1,
          competitionId: 564,
          homeTeamId: 83,
          awayTeamId: 90,
          homeTeamName: 'Nantes',
          awayTeamName: 'Nîmes',
          homeTeamShortName: 'ABC',
          awayTeamShortName: 'DEF',
          competitionType: CompetitionType.league,
          status: status,
          stateId: stateId,
          roundName: '8',
          startingAt: DateTime(2026, 3, 14).toIso8601String(),
        ),
    ]));
    await tester.pumpAndSettle();

    for (final id in [101, 102]) {
      final card = find.byKey(ValueKey('search-event-$id'));
      await tester.ensureVisible(card);
      expect(
        find.descendant(
          of: card,
          matching: find.text(id == 101 ? 'Postponed' : 'Cancelled'),
        ),
        findsOneWidget,
      );
      expect(find.descendant(of: card, matching: find.text('ABC')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('DEF')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Sat, Mar 14')),
          findsNothing);
      final inkWell = tester.widget<InkWell>(find.ancestor(
        of: card,
        matching: find.byType(InkWell),
      ));
      expect(inkWell.onTap, isNull);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('search-scaffold')), findsOneWidget);
    }

    final scheduledCard = find.byKey(const ValueKey('search-event-103'));
    await tester.ensureVisible(scheduledCard);
    expect(find.descendant(of: scheduledCard, matching: find.text('ABC')),
        findsOneWidget);
    expect(find.descendant(of: scheduledCard, matching: find.text('DEF')),
        findsOneWidget);
    await tester.tap(scheduledCard);
    await tester.pumpAndSettle();
    expect(find.text('Match ID 103'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        'unavailable search card fits compact and tall ${dark ? 'dark' : 'light'} screens',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 568);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repo = _Search();
      await _pump(tester, repo, dark: dark);
      await _query(tester, 'Nantes');
      repo.pending.single.complete(SearchResults(fixtures: [
        Fixture(
          fixtureId: 104,
          seasonId: 1,
          competitionId: 564,
          homeTeamId: 99991,
          awayTeamId: 99992,
          homeTeamName: 'Marseille',
          awayTeamName: 'Nîmes',
          homeTeamShortName: 'OM',
          awayTeamShortName: 'Nîmes',
          competitionType: CompetitionType.league,
          status: FixtureStatus.upcoming,
          stateId: 10,
          roundName: '8',
          startingAt: DateTime(2026, 3, 14).toIso8601String(),
        ),
      ]));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey('search-event-104'));
      final container = tester.widget<Container>(card);
      final decoration = container.decoration! as BoxDecoration;
      expect(container.padding, const EdgeInsets.all(16));
      expect(decoration.borderRadius, BorderRadius.circular(24));
      expect(decoration.color,
          dark ? app_style.AppPalette.darkGrey : app_style.AppPalette.white);
      expect(find.descendant(of: card, matching: find.text('Postponed')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('MAR')),
          findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('NÎM')),
          findsOneWidget);
      expect(
        find
            .descendant(of: card, matching: find.byType(Opacity))
            .evaluate()
            .where((element) => (element.widget as Opacity).opacity == 0.3)
            .length,
        2,
      );
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(430, 932);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'empty input shows a prompt without fabricated recents or a request',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    final searchBar = tester.widget<Container>(
      find.byKey(const ValueKey('global-search-bar')),
    );
    expect(
      (searchBar.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(8),
    );
    expect((searchBar.decoration as BoxDecoration).color,
        app_style.AppPalette.lightGreyBox);
    expect(searchBar.clipBehavior, Clip.antiAlias);
    expect(find.byKey(const ValueKey('search-prompt')), findsOneWidget);
    expect(find.text('RECENTS'), findsNothing);
    expect(repo.calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark search bar keeps its card background', (tester) async {
    await _pump(tester, _Search(), dark: true);
    final searchBar = tester.widget<Container>(
      find.byKey(const ValueKey('global-search-bar')),
    );
    expect((searchBar.decoration as BoxDecoration).color,
        app_style.AppPalette.darkGrey);
  });

  testWidgets('search bar fits compact and tall screens', (tester) async {
    await _pump(tester, _Search());
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(
          tester.getRect(find.byKey(const ValueKey('global-search-bar'))).right,
          lessThanOrEqualTo(size.width));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('search category tabs use the 42px compact design',
      (tester) async {
    final repo = _Search();
    await _pump(tester, repo);
    await _query(tester, 'Example');
    repo.pending.single.complete(_results);
    await tester.pumpAndSettle();

    final allTab = find.byKey(const ValueKey('search-tab-all'));
    final tabContainer = find.descendant(
      of: allTab,
      matching: find.byType(AnimatedContainer),
    );
    final tab = tester.widget<AnimatedContainer>(tabContainer);
    expect(tester.getSize(tabContainer).height, 42);
    expect(tab.padding, const EdgeInsets.symmetric(horizontal: 16));
    expect((tab.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(16));
    expect(
        tester
            .widget<Text>(
                find.descendant(of: allTab, matching: find.text('ALL')))
            .style!
            .fontSize,
        14);

    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpAndSettle();
      expect(tester.getSize(allTab).height, 42);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
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
