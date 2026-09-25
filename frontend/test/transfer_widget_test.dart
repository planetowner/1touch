import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_transfer_window.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await (FontLoader('Archivo')
          ..addFont(rootBundle.load('assets/fonts/Archivo-Variable.ttf')))
        .load();
  });

  Widget buildSubject({
    required int teamId,
    required TransferRepository repository,
    VoidCallback? onUnavailable,
    Locale locale = const Locale('en'),
  }) {
    return MaterialApp(
      locale: locale,
      supportedLocales: appSupportedLocales,
      localizationsDelegates: appLocalizationDelegates,
      theme: whitetheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Transfer(
            teams: <String, dynamic>{'id': teamId},
            repository: repository,
            onUnavailable: onUnavailable,
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
        incoming: [
          TransferEntry(
            transferId: 1,
            playerId: 101,
            playerName: 'Incoming Player With A Long Name',
            direction: TransferDirection.incoming,
            typeId: 219,
            otherTeamId: 10,
            otherTeamName: 'Source Football Club',
            displayType: 'Transfer',
            amount: 8500000,
            transferDate: '2026-01-10',
            contractStartDate: DateTime.utc(2026, 1, 10),
            contractEndDate: DateTime.utc(2030, 6, 30),
          ),
          TransferEntry(
            transferId: 2,
            playerId: 102,
            playerName: 'Loan Player',
            direction: TransferDirection.incoming,
            typeId: 218,
            otherTeamId: 11,
            otherTeamName: 'Loan Source FC',
            displayType: 'Loan',
            transferDate: '2026-01-20',
            contractStartDate: DateTime.utc(2026, 1, 20),
          ),
          TransferEntry(
            transferId: 4,
            playerId: 104,
            playerName: 'Unknown Fee Player',
            direction: TransferDirection.incoming,
            typeId: 219,
            otherTeamId: 12,
            otherTeamName: 'Unknown Fee FC',
            displayType: 'Transfer',
            transferDate: '2026-01-15',
            contractEndDate: DateTime.utc(2029, 6, 30),
          ),
        ],
        outgoing: const [
          TransferEntry(
            transferId: 3,
            playerId: 103,
            playerName: 'Outgoing Player',
            direction: TransferDirection.outgoing,
            typeId: 220,
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
    expect(find.text('€8.5m'), findsOneWidget);
    expect(find.text('Loan'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('FROM'), findsNWidgets(3));
    expect(find.text('DATE'), findsNothing);
    expect(find.text('Jan 2026 – Jun 2030'), findsOneWidget);
    expect(find.text('Jan 2026 – -'), findsOneWidget);
    expect(find.text('- – Jun 2029'), findsOneWidget);
    expect(
      find.byTooltip('Complete contract dates are currently unavailable.'),
      findsNWidgets(2),
    );
    expect(find.text('Outgoing Player'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('transfer-out-toggle')));
    await tester.pump();

    expect(find.text('Incoming Player With A Long Name'), findsNothing);
    expect(find.text('Outgoing Player'), findsOneWidget);
    expect(find.text('Free Transfer'), findsOneWidget);
    expect(find.text('TO'), findsOneWidget);
    expect(find.text('-'), findsOneWidget);
    expect(
      find.byTooltip('Complete contract dates are currently unavailable.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer player opens the player page', (tester) async {
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 summer',
        incoming: const [
          TransferEntry(
            transferId: 1,
            playerId: 101,
            playerName: 'Transfer Player',
            direction: TransferDirection.incoming,
            typeId: 219,
          ),
        ],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);
    final router = GoRouter(
      initialLocation: '/team',
      routes: [
        GoRoute(
          path: '/team',
          builder: (_, __) => Scaffold(
            body: Transfer(
              teams: const <String, dynamic>{'id': 9},
              repository: repository,
            ),
          ),
        ),
        GoRoute(
          path: '/players/:id',
          builder: (_, state) => Text('Player ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-1')));
    await tester.pumpAndSettle();

    expect(find.text('Player 101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('player name uses space left by a short transfer value',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 summer',
        incoming: const [
          TransferEntry(
            transferId: 77,
            playerId: 1077,
            playerName: 'Dominik Livakovic',
            direction: TransferDirection.incoming,
            typeId: 219,
            amount: 8500000,
          ),
        ],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpAndSettle();

    final name = find.byKey(const ValueKey('transfer-player-name-77'));
    expect(name, findsOneWidget);
    expect(tester.widget<Text>(name).style, Body1_b.style);
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason:
          '${paragraph.text.toPlainText()} needs ${paragraph.getMaxIntrinsicWidth(double.infinity)}px but has ${paragraph.size.width}px',
    );
    final value = find.byKey(const ValueKey('transfer-value-77'));
    expect(value, findsOneWidget);
    expect(tester.widget<Text>(value).style, Body1_b.style);
    expect(
      tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows common transfer type labels without truncating them',
      (tester) async {
    useCompactScreen(tester);
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 summer',
        incoming: const [
          TransferEntry(
            transferId: 81,
            playerId: 1081,
            playerName: 'Free Player',
            direction: TransferDirection.incoming,
            typeId: 220,
            displayType: 'Free Transfer',
          ),
          TransferEntry(
            transferId: 82,
            playerId: 1082,
            playerName: 'Unknown Player',
            direction: TransferDirection.incoming,
            typeId: 219,
          ),
          TransferEntry(
            transferId: 83,
            playerId: 1083,
            playerName: 'Loan Player',
            direction: TransferDirection.incoming,
            typeId: 218,
            displayType: 'On Loan',
          ),
        ],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(teamId: 9, repository: repository));
    await tester.pumpAndSettle();

    for (final transferId in [81, 82, 83]) {
      final value = find.byKey(ValueKey('transfer-value-$transferId'));
      expect(value, findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
        isFalse,
        reason: '${tester.widget<Text>(value).data} should fit at 320px',
      );
    }
    expect(find.text('Free Transfer'), findsOneWidget);
    expect(find.text('Unknown'), findsOneWidget);
    expect(find.text('On Loan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows Korean transfer type labels in full with Body1_b',
      (tester) async {
    useCompactScreen(tester);
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 summer',
        incoming: const [
          TransferEntry(
            transferId: 91,
            playerId: 1091,
            playerName: 'Free Player',
            direction: TransferDirection.incoming,
            typeId: 220,
            displayType: 'Free Transfer',
          ),
          TransferEntry(
            transferId: 92,
            playerId: 1092,
            playerName: 'Unknown Player',
            direction: TransferDirection.incoming,
            typeId: 219,
          ),
          TransferEntry(
            transferId: 93,
            playerId: 1093,
            playerName: 'Loan Player',
            direction: TransferDirection.outgoing,
            typeId: 218,
            displayType: 'On Loan',
          ),
          TransferEntry(
            transferId: 94,
            playerId: 1094,
            playerName: 'Returning Player',
            direction: TransferDirection.incoming,
            typeId: 9688,
            displayType: 'Return from loan',
          ),
        ],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(
      teamId: 9,
      repository: repository,
      locale: const Locale('ko'),
    ));
    await tester.pumpAndSettle();

    const expectedLabels = <int, String>{
      91: '자유 계약',
      92: '정보 없음',
      93: '임대',
      94: '임대 복귀',
    };
    for (final entry in expectedLabels.entries) {
      final value = find.byKey(ValueKey('transfer-value-${entry.key}'));
      expect(value, findsOneWidget);
      expect(tester.widget<Text>(value).data, entry.value);
      expect(tester.widget<Text>(value).style, Body1_b.style);
      expect(
        tester.renderObject<RenderParagraph>(value).didExceedMaxLines,
        isFalse,
        reason: '${entry.value} should fit at 320px',
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('does not show a legacy jersey prefix in a Korean player name',
      (tester) async {
    final repository = _TestTransferRepository(
      (teamId) async => TeamTransferWindow(
        teamId: teamId,
        windowKey: '2026 summer',
        incoming: const [
          TransferEntry(
            transferId: 95,
            playerId: 1095,
            playerName: '13번 도미닉 리바코비치',
            direction: TransferDirection.incoming,
            typeId: 220,
            displayType: 'Free Transfer',
          ),
        ],
        outgoing: const [],
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(buildSubject(
      teamId: 9,
      repository: repository,
      locale: const Locale('ko'),
    ));
    await tester.pumpAndSettle();

    final name = find.byKey(const ValueKey('transfer-player-name-95'));
    expect(name, findsOneWidget);
    expect(tester.widget<Text>(name).data, '도미닉 리바코비치');
    expect(find.text('13번 도미닉 리바코비치'), findsNothing);
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

  testWidgets('reports and hides an unavailable feature', (tester) async {
    var unavailableCalls = 0;
    final repository = _TestTransferRepository(
      (teamId) async => throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Transfers',
      ),
    );
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      buildSubject(
        teamId: 9,
        repository: repository,
        onUnavailable: () => unavailableCalls += 1,
      ),
    );
    await tester.pump();

    expect(unavailableCalls, 1);
    expect(find.byKey(const ValueKey('transfer-unavailable')), findsOneWidget);
    expect(find.byKey(const ValueKey('transfer-error')), findsNothing);
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
            typeId: 219,
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
            typeId: 219,
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
