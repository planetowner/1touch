import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/data/team_probability/team_probability_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_probability.dart';
import 'package:onetouch/screens/TeamScreen_tabs/analysis.dart';

void main() {
  testWidgets('renders backend cards in the existing two-column design',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = _snapshot(cards: [
      _card('league_winner', probability: 0.77009, change: 1.245),
      _card('top_4', probability: 0.99997, change: 0),
      _card('top_6', probability: 0.42, change: null),
      _card('direct_relegation', probability: 0.036, change: -2.5),
    ]);
    final repository = _StubProbabilityRepository(initial: {83: snapshot});

    await tester.pumpWidget(
      _app(repository: repository, theme: app_style.whitetheme),
    );
    await tester.pump();

    expect(find.text('PROBABILITY'), findsOneWidget);
    expect(
      tester
          .widget<Padding>(
            find.byKey(const ValueKey('team-probability-section')),
          )
          .padding,
      const EdgeInsets.fromLTRB(24, 32, 24, 0),
    );
    expect(find.text('Chances to win\nLEAGUE Trophy'), findsOneWidget);
    expect(find.text('Chances to finish\nTOP 4'), findsOneWidget);
    expect(find.text('Chances to finish\nTOP 6'), findsOneWidget);
    expect(find.text('Chances of\nRELEGATION'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('team-probability-value-league_winner')),
      findsOneWidget,
    );
    expect(find.text('77'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('team-probability-value-league_winner'),
            ),
          )
          .style
          ?.fontSize,
      48,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(
              const ValueKey('team-probability-percent-league_winner'),
            ),
          )
          .style
          ?.fontSize,
      20,
    );
    final probabilitySurface = tester.widget<Container>(
      find.byKey(
        const ValueKey('team-probability-surface-league_winner'),
      ),
    );
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('team-probability-surface-league_winner'),
        ),
      ),
      const Size(165, 165),
    );
    expect(
      (probabilitySurface.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(24),
    );
    expect(
      (probabilitySurface.decoration as BoxDecoration).boxShadow,
      app_style.lightModeCardShadows,
    );

    final upIcon = tester.widget<Icon>(
      find.byKey(
        const ValueKey('team-probability-delta-icon-league_winner'),
      ),
    );
    expect(upIcon.icon, Icons.arrow_drop_up);
    expect(upIcon.color, const Color(0xFF36CC7A));
    expect(find.text('1.25%'), findsOneWidget);

    final downIcon = tester.widget<Icon>(
      find.byKey(
        const ValueKey('team-probability-delta-icon-direct_relegation'),
      ),
    );
    expect(downIcon.icon, Icons.arrow_drop_down);
    expect(downIcon.color, const Color(0xFFFF5C5C));
    expect(find.text('2.5%'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('team-probability-delta-icon-top_4')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('team-probability-delta-icon-top_6')),
      findsNothing,
    );
    final probabilityTop = tester.getTopLeft(
      find.byKey(
        const ValueKey('team-probability-value-league_winner'),
      ),
    );
    final deltaBottom = tester.getBottomLeft(
      find.byKey(
        const ValueKey('team-probability-delta-row-league_winner'),
      ),
    );
    expect(probabilityTop.dy - deltaBottom.dy, closeTo(4, 1));
    expect(
      tester
          .getTopLeft(
            find.byKey(
                const ValueKey('team-probability-delta-row-league_winner')),
          )
          .dx,
      tester
          .getTopLeft(
            find.byKey(const ValueKey('team-probability-value-league_winner')),
          )
          .dx,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('aligns one-line and two-line probability card contents',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _StubProbabilityRepository(
      initial: {
        83: _snapshot(cards: [
          _card('custom'),
          _card('league_winner'),
          _card('ucl_winner'),
        ]),
      },
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();

    expect(find.text('Chances to win\nUCL Trophy'), findsOneWidget);
    final oneLineTitle = find.byKey(
      const ValueKey('team-probability-title-slot-custom'),
    );
    final twoLineTitle = find.byKey(
      const ValueKey('team-probability-title-slot-league_winner'),
    );
    expect(tester.getSize(oneLineTitle).height, 39);
    expect(tester.getSize(twoLineTitle).height, 39);

    final oneLineFooter = tester.getTopLeft(
      find.byKey(const ValueKey('team-probability-footer-custom')),
    );
    final twoLineFooter = tester.getTopLeft(
      find.byKey(const ValueKey('team-probability-footer-league_winner')),
    );
    expect(oneLineFooter.dy, twoLineFooter.dy);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps every Korean probability card title on one line',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _StubProbabilityRepository(
      initial: {
        83: _snapshot(cards: [
          _card('ucl_winner'),
          _card('top_4'),
          _card('relegation_playoff'),
        ]),
      },
    );

    await tester.pumpWidget(
      _app(repository: repository, locale: const Locale('ko')),
    );
    await tester.pump();

    for (final event in ['ucl_winner', 'top_4', 'relegation_playoff']) {
      final title = tester.widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('team-probability-title-slot-$event')),
          matching: find.byType(Text),
        ),
      );
      expect(title.maxLines, 1);
      expect(title.softWrap, isFalse);
      expect(title.data, isNot(contains('\n')));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides probability when the backend marks it unavailable',
      (tester) async {
    final repository = _StubProbabilityRepository(
      loader: (_) async => throw const TeamFeatureUnavailableException(
        teamId: 83,
        feature: 'Probability',
      ),
    );

    await tester.pumpWidget(_app(repository: repository));
    expect(
      find.byKey(const ValueKey('team-probability-loading')),
      findsOneWidget,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('team-probability-section')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('retries a transient probability failure', (tester) async {
    var attempts = 0;
    final repository = _StubProbabilityRepository(
      loader: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('temporary failure');
        return _snapshot(cards: [_card('league_winner')]);
      },
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('team-probability-retry')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('team-probability-retry')));
    await tester.pump();
    await tester.pump();

    expect(attempts, 2);
    expect(
      find.byKey(const ValueKey('team-probability-card-league_winner')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('reloads probability when the displayed team changes',
      (tester) async {
    final repository = _StubProbabilityRepository(
      loader: (teamId) async => _snapshot(
        teamId: teamId,
        cards: [_card(teamId == 83 ? 'league_winner' : 'top_6')],
      ),
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('team-probability-card-league_winner')),
      findsOneWidget,
    );

    await tester.pumpWidget(_app(repository: repository, teamId: 19));
    await tester.pump();

    expect(repository.requestedTeamIds, [83, 19]);
    expect(
      find.byKey(const ValueKey('team-probability-card-league_winner')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('team-probability-card-top_6')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the selected probability detail', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _StubProbabilityRepository(
      initial: {
        83: _snapshot(cards: [_card('league_winner', probability: 0.32)]),
      },
    );

    await tester.pumpWidget(_app(repository: repository));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('team-probability-card-league_winner')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('team-probability-detail-screen')),
      findsOneWidget,
    );
    expect(find.text('Probability'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  required TeamProbabilityRepository repository,
  int teamId = 83,
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: const [Locale('en'), Locale('ko')],
    localizationsDelegates: appLocalizationDelegates,
    theme: theme ?? app_style.darktheme,
    home: Scaffold(
      body: SingleChildScrollView(
        child: ProbabilitySection(
          teamId: teamId,
          repository: repository,
        ),
      ),
    ),
  );
}

TeamProbabilitySnapshot _snapshot({
  int teamId = 83,
  required List<TeamProbabilityCard> cards,
}) {
  return TeamProbabilitySnapshot(
    teamId: teamId,
    teamName: 'Team $teamId',
    competitionId: 564,
    seasonId: 27965,
    seasonName: '2026/2027',
    asOf: DateTime.utc(2026, 9, 18),
    maximumPoints: 114,
    positions: const [
      TeamPositionProbability(position: 1, probability: 0.5),
    ],
    projectedPoints: const TeamProjectedPoints(
      mean: 82.4,
      likelyRange: TeamPointsInterval(lower: 75, upper: 90),
      changePoints: 1.2,
    ),
    comparison: TeamProbabilityComparison(
      available: true,
      asOf: DateTime.utc(2026, 9, 16),
    ),
    cards: cards,
    history: const [],
    pendingOutcomes: const [],
  );
}

TeamProbabilityCard _card(
  String event, {
  double probability = 0.5,
  double? change = 1,
}) {
  return TeamProbabilityCard(
    event: event,
    competitionId: 564,
    category: 'TEST',
    probability: probability,
    changePercentagePoints: change,
    entropy: null,
  );
}

class _StubProbabilityRepository implements TeamProbabilityRepository {
  _StubProbabilityRepository({
    Map<int, TeamProbabilitySnapshot> initial = const {},
    this.loader,
  }) : _cached = ValueNotifier({
          for (final entry in initial.entries)
            TeamProbabilityQuery(teamId: entry.key): entry.value,
        });

  final Future<TeamProbabilitySnapshot> Function(int teamId)? loader;
  final ValueNotifier<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      _cached;
  final List<int> requestedTeamIds = [];

  @override
  ValueListenable<Map<TeamProbabilityQuery, TeamProbabilitySnapshot>>
      get cachedSnapshots => _cached;

  @override
  TeamProbabilitySnapshot? cachedForTeam(int teamId, {int? seasonId}) {
    return _cached
        .value[TeamProbabilityQuery(teamId: teamId, seasonId: seasonId)];
  }

  @override
  Future<TeamProbabilitySnapshot> loadForTeam(
    int teamId, {
    int? seasonId,
  }) async {
    requestedTeamIds.add(teamId);
    final cached = cachedForTeam(teamId, seasonId: seasonId);
    if (cached != null) return cached;
    final load = loader;
    if (load == null) throw StateError('No probability for team $teamId.');
    final snapshot = await load(teamId);
    final query = TeamProbabilityQuery(teamId: teamId, seasonId: seasonId);
    _cached.value = Map.unmodifiable({..._cached.value, query: snapshot});
    return snapshot;
  }
}
