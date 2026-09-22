import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/features/team/best_eleven/team_best_eleven_section.dart';
import 'package:onetouch/models/team_best_eleven.dart';

void main() {
  void useScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  for (final variant in TeamBestElevenVariant.values) {
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      for (final dark in [false, true]) {
        testWidgets('jersey numbers in $variant at $size dark=$dark',
            (tester) async {
          useScreen(tester, size);
          final repository = _TestBestElevenRepository((query) async => _lineup(
                teamId: query.teamId,
                playerPrefix: 'Number',
                jerseyNumbers: const {0: 1, 1: 27, 10: 99},
              ));
          addTearDown(repository.dispose);
          await tester.pumpWidget(MaterialApp(
            theme: dark ? darktheme : whitetheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: TeamBestElevenSection(
                  teamId: 503,
                  variant: variant,
                  repository: repository,
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          expect(find.text('1'), findsOneWidget);
          expect(find.text('27'), findsOneWidget);
          expect(find.text('99'), findsOneWidget);
          expect(find.text('—'), findsNWidgets(8));
          expect(find.text('##'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  Widget buildSubject({
    required int teamId,
    required BestElevenRepository repository,
    VoidCallback? onUnavailable,
  }) {
    return MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeamBestElevenSection(
            teamId: teamId,
            variant: TeamBestElevenVariant.overview,
            repository: repository,
            onUnavailable: onUnavailable,
          ),
        ),
      ),
    );
  }

  Widget buildAnalysisSubject({
    required int? teamId,
    required BestElevenRepository repository,
  }) {
    return MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeamBestElevenSection(
            teamId: teamId,
            variant: TeamBestElevenVariant.analysis,
            repository: repository,
          ),
        ),
      ),
    );
  }

  testWidgets('loads and renders repository players at compact width',
      (tester) async {
    useScreen(tester, const Size(320, 568));
    final result = Completer<TeamBestEleven?>();
    final repository = _TestBestElevenRepository((_) => result.future);
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));

    expect(find.byKey(const ValueKey('best-eleven-loading')), findsOneWidget);

    result.complete(_lineup(teamId: 9, playerPrefix: 'Compact'));
    await tester.pumpAndSettle();

    expect(find.text('Compact0'), findsOneWidget);
    expect(find.text('Compact10'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('##'), findsNothing);
    expect(find.byType(BestElevenPitch), findsOneWidget);
    final bestElevenCard = tester.widget<Container>(
      find.byKey(const ValueKey('team-best-eleven-card')),
    );
    expect(
      (bestElevenCard.decoration as BoxDecoration).boxShadow,
      lightModeCardShadows,
    );
    final playerDot = tester.widget<Container>(
      find.byKey(const ValueKey('best-eleven-player-dot-1:1')),
    );
    final playerDotColor = (playerDot.decoration as BoxDecoration).color!;
    final jerseyNumber = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('best-eleven-player-dot-1:1')),
        matching: find.text('1'),
      ),
    );
    expect(playerDotColor, const Color(0xFF5FAFF1));
    expect(jerseyNumber.style!.color, Colors.black);
    expect(
      ColorUtils.getContrastRatio(playerDotColor, jerseyNumber.style!.color!),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a taller phone without layout exceptions', (tester) async {
    useScreen(tester, const Size(393, 852));
    final repository = _TestBestElevenRepository(
      (query) async => _lineup(teamId: query.teamId, playerPrefix: 'Tall'),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpAndSettle();

    expect(find.text('Tall0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state when no lineup is available',
      (tester) async {
    final repository = _TestBestElevenRepository((_) async => null);
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('best-eleven-empty')), findsOneWidget);
    expect(find.text('No best eleven available'), findsOneWidget);
  });

  testWidgets('reports and hides unavailable overview content when requested',
      (tester) async {
    var unavailableCalls = 0;
    final repository = _TestBestElevenRepository((_) async => null);
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildSubject(
        teamId: 9,
        repository: repository,
        onUnavailable: () => unavailableCalls += 1,
      ),
    );
    await tester.pumpAndSettle();

    expect(unavailableCalls, 1);
    expect(
      find.byKey(const ValueKey('best-eleven-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('best-eleven-empty')), findsNothing);
  });

  testWidgets('shows an error and retries the repository request',
      (tester) async {
    var attempt = 0;
    final repository = _TestBestElevenRepository((query) async {
      attempt += 1;
      if (attempt == 1) throw StateError('temporary failure');
      return _lineup(teamId: query.teamId, playerPrefix: 'Retry');
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('best-eleven-error')), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.text('Retry0'), findsOneWidget);
  });

  testWidgets('ignores a stale lineup after the selected team changes',
      (tester) async {
    final firstResult = Completer<TeamBestEleven?>();
    final secondResult = Completer<TeamBestEleven?>();
    final repository = _TestBestElevenRepository(
      (query) => query.teamId == 9 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpWidget(buildSubject(teamId: 20, repository: repository));

    firstResult.complete(_lineup(teamId: 9, playerPrefix: 'Stale'));
    await tester.pump();

    expect(find.text('Stale0'), findsNothing);
    expect(find.byKey(const ValueKey('best-eleven-loading')), findsOneWidget);

    secondResult.complete(_lineup(teamId: 20, playerPrefix: 'Current'));
    await tester.pumpAndSettle();

    expect(find.text('Stale0'), findsNothing);
    expect(find.text('Current0'), findsOneWidget);
  });

  testWidgets('Analysis loads real formation options and switches lineups',
      (tester) async {
    useScreen(tester, const Size(320, 568));
    final requestedFormations = <String?>[];
    const formations = [
      BestElevenFormationOption(
        formation: '4-3-3',
        isDefault: true,
        matchesUsed: 20,
        totalValidMatches: 30,
        usagePercentage: 66.7,
      ),
      BestElevenFormationOption(
        formation: '3-5-2',
        isDefault: false,
      ),
    ];
    final repository = _TestBestElevenRepository((query) async {
      requestedFormations.add(query.formation);
      final formation = query.formation ?? '4-3-3';
      return _lineup(
        teamId: query.teamId,
        playerPrefix: formation == '4-3-3' ? 'Default' : 'Alternate',
        formation: formation,
        formations: formations,
      );
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildAnalysisSubject(teamId: 9, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.text('4-3-3 (66.7%)'), findsOneWidget);
    expect(find.textContaining('90%'), findsNothing);
    expect(find.text('Default0'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('analysis-formation-filter')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('3-5-2').last);
    await tester.pumpAndSettle();

    expect(requestedFormations, [null, '3-5-2']);
    expect(find.text('Default0'), findsNothing);
    expect(find.text('Alternate0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Analysis shows an error and retries its selected query',
      (tester) async {
    var attempt = 0;
    final repository = _TestBestElevenRepository((query) async {
      attempt += 1;
      if (attempt == 1) throw StateError('temporary failure');
      return _lineup(teamId: query.teamId, playerPrefix: 'Recovered');
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildAnalysisSubject(teamId: 9, repository: repository),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('analysis-best-eleven-error')),
      findsOneWidget,
    );

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.text('Recovered0'), findsOneWidget);
  });

  testWidgets('Analysis ignores a stale lineup after its team changes',
      (tester) async {
    final firstResult = Completer<TeamBestEleven?>();
    final secondResult = Completer<TeamBestEleven?>();
    final repository = _TestBestElevenRepository(
      (query) => query.teamId == 9 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildAnalysisSubject(teamId: 9, repository: repository),
    );
    await tester.pumpWidget(
      buildAnalysisSubject(teamId: 20, repository: repository),
    );

    firstResult.complete(_lineup(teamId: 9, playerPrefix: 'OldAnalysis'));
    await tester.pump();

    expect(find.text('OldAnalysis0'), findsNothing);
    expect(
      find.byKey(const ValueKey('analysis-best-eleven-loading')),
      findsOneWidget,
    );

    secondResult.complete(
      _lineup(teamId: 20, playerPrefix: 'NewAnalysis'),
    );
    await tester.pumpAndSettle();

    expect(find.text('OldAnalysis0'), findsNothing);
    expect(find.text('NewAnalysis0'), findsOneWidget);
  });

  testWidgets('Analysis does not invent a Barcelona fallback without a team',
      (tester) async {
    var loadCount = 0;
    final repository = _TestBestElevenRepository((query) async {
      loadCount += 1;
      return _lineup(teamId: query.teamId, playerPrefix: 'Unexpected');
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildAnalysisSubject(teamId: null, repository: repository),
    );
    await tester.pumpAndSettle();

    expect(loadCount, 0);
    expect(
      find.byKey(const ValueKey('analysis-best-eleven-empty')),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('analysis-formation-filter')), findsNothing);
  });
}

TeamBestEleven _lineup({
  required int teamId,
  required String playerPrefix,
  String formation = '4-3-3',
  List<BestElevenFormationOption>? formations,
  Map<int, int> jerseyNumbers = const {},
}) {
  const slots = [
    '1:1',
    '2:1',
    '2:2',
    '2:3',
    '2:4',
    '3:1',
    '3:2',
    '3:3',
    '4:1',
    '4:2',
    '4:3',
  ];
  return TeamBestEleven(
    teamId: teamId,
    seasonId: 25583,
    formation: formation,
    formations: formations ??
        [
          BestElevenFormationOption(
            formation: formation,
            isDefault: true,
          ),
        ],
    players: [
      for (var index = 0; index < slots.length; index += 1)
        BestElevenEntry(
          slotKey: slots[index],
          slotIndex: index,
          playerId: 100 + index,
          playerName: '$playerPrefix$index',
          starts: 10,
          jerseyNumber:
              jerseyNumbers.isEmpty ? index + 1 : jerseyNumbers[index],
        ),
    ],
  );
}

class _TestBestElevenRepository implements BestElevenRepository {
  _TestBestElevenRepository(this._loader);

  final Future<TeamBestEleven?> Function(BestElevenQuery query) _loader;
  final ValueNotifier<Map<BestElevenQuery, TeamBestEleven>> _cachedLineups =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<BestElevenQuery, TeamBestEleven>> get cachedLineups =>
      _cachedLineups;

  @override
  TeamBestEleven? cachedForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) {
    return _cachedLineups.value[BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    )];
  }

  @override
  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) async {
    final query = BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    );
    final cached = _cachedLineups.value[query];
    if (cached != null) return cached;

    final lineup = await _loader(query);
    if (lineup != null) {
      _cachedLineups.value = Map.unmodifiable({
        ..._cachedLineups.value,
        query: lineup,
      });
    }
    return lineup;
  }

  void dispose() => _cachedLineups.dispose();
}
