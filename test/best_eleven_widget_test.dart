import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/models/team_best_eleven.dart';

void main() {
  Widget buildSubject({
    required int teamId,
    required BestElevenRepository repository,
  }) {
    return MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: BestXI(
            teams: <String, dynamic>{'id': teamId},
            repository: repository,
          ),
        ),
      ),
    );
  }

  void useScreen(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    expect(find.byType(BestElevenPitch), findsOneWidget);
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
}

TeamBestEleven _lineup({
  required int teamId,
  required String playerPrefix,
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
    formation: '4-3-3',
    formations: const [
      BestElevenFormationOption(
        formation: '4-3-3',
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
          totalMinutes: 900,
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
