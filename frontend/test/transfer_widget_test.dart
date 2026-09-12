import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/models/team_transfer_window.dart';

void main() {
  Widget buildSubject({
    required int teamId,
    required TransferRepository repository,
  }) {
    return MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Transfer(
            teams: <String, dynamic>{'id': teamId},
            repository: repository,
          ),
        ),
      ),
    );
  }

  void useCompactScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders repository entries and switches transfer direction',
      (tester) async {
    useCompactScreen(tester);
    final result = Completer<TeamTransferWindow>();
    final repository = _TestTransferRepository((_) => result.future);
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));

    expect(find.byKey(const ValueKey('transfer-loading')), findsOneWidget);

    result.complete(
      TeamTransferWindow(
        teamId: 9,
        windowKey: '2026 winter',
        incoming: const [
          TransferEntry(
            transferId: 1,
            playerId: 101,
            playerName: 'Incoming Player With A Long Name',
            direction: TransferDirection.incoming,
            otherTeamId: 10,
            otherTeamName: 'Source Football Club',
            displayType: '€8.5M',
            amount: 8500000,
            transferDate: '2026-01-10',
          ),
          TransferEntry(
            transferId: 2,
            playerId: 102,
            playerName: 'Loan Player',
            direction: TransferDirection.incoming,
            otherTeamId: 11,
            otherTeamName: 'Loan Source FC',
            displayType: 'Loan',
            transferDate: '2026-01-20',
          ),
        ],
        outgoing: const [
          TransferEntry(
            transferId: 3,
            playerId: 103,
            playerName: 'Outgoing Player',
            direction: TransferDirection.outgoing,
            otherTeamId: 20,
            otherTeamName: 'Destination FC',
            displayType: 'Free Transfer',
            amount: 0,
            transferDate: '2026-01-25',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Incoming Player With A Long Name'), findsOneWidget);
    expect(find.text('€8.5M'), findsOneWidget);
    expect(find.text('Loan'), findsOneWidget);
    expect(find.text('FROM'), findsNWidgets(2));
    expect(find.text('Outgoing Player'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('transfer-out-toggle')));
    await tester.pump();

    expect(find.text('Incoming Player With A Long Name'), findsNothing);
    expect(find.text('Outgoing Player'), findsOneWidget);
    expect(find.text('Free Transfer'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state for a window without transfers',
      (tester) async {
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 winter',
        incoming: const [],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('transfer-empty')), findsOneWidget);
    expect(find.text('No transfers'), findsOneWidget);
  });

  testWidgets('shows an error and retries the repository request',
      (tester) async {
    var attempt = 0;
    final repository = _TestTransferRepository((teamId) async {
      attempt += 1;
      if (attempt == 1) throw StateError('temporary failure');
      return TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 winter',
        incoming: const [],
        outgoing: const [],
      );
    });
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('transfer-error')), findsOneWidget);

    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();

    expect(attempt, 2);
    expect(find.byKey(const ValueKey('transfer-empty')), findsOneWidget);
  });

  testWidgets('ignores a stale result after the selected team changes',
      (tester) async {
    final firstResult = Completer<TeamTransferWindow>();
    final secondResult = Completer<TeamTransferWindow>();
    final repository = _TestTransferRepository(
      (teamId) => teamId == 9 ? firstResult.future : secondResult.future,
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpWidget(buildSubject(teamId: 20, repository: repository));

    firstResult.complete(
      TeamTransferWindow(
        teamId: 9,
        windowKey: '2026 winter',
        incoming: const [
          TransferEntry(
            transferId: 10,
            playerId: 110,
            playerName: 'Stale Player',
            direction: TransferDirection.incoming,
          ),
        ],
        outgoing: const [],
      ),
    );
    await tester.pump();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.byKey(const ValueKey('transfer-loading')), findsOneWidget);

    secondResult.complete(
      TeamTransferWindow(
        teamId: 20,
        windowKey: '2026 winter',
        incoming: const [
          TransferEntry(
            transferId: 20,
            playerId: 120,
            playerName: 'Current Player',
            direction: TransferDirection.incoming,
          ),
        ],
        outgoing: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stale Player'), findsNothing);
    expect(find.text('Current Player'), findsOneWidget);
  });
}

class _TestTransferRepository implements TransferRepository {
  _TestTransferRepository(this._loader);

  final Future<TeamTransferWindow> Function(int teamId) _loader;
  final ValueNotifier<Map<int, TeamTransferWindow>> _cachedWindows =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows =>
      _cachedWindows;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => _cachedWindows.value[teamId];

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final window = await _loader(teamId);
    _cachedWindows.value = Map.unmodifiable({
      ..._cachedWindows.value,
      teamId: window,
    });
    return window;
  }

  void dispose() => _cachedWindows.dispose();
}
