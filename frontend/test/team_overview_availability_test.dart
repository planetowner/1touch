import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/models/team_best_eleven.dart';
import 'package:onetouch/models/team_injury_report.dart';
import 'package:onetouch/models/team_transfer_window.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/screens/TeamScreen_tabs/overview.dart';

void main() {
  for (final (size, locale) in [
    (const Size(320, 568), const Locale('en')),
    (const Size(430, 932), const Locale('ko')),
  ]) {
    testWidgets('BEST XI help opens beside the heading at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bestElevenRepository = _AvailableBestElevenRepository();
      final injuryRepository = _UnavailableInjuryRepository();
      final transferRepository = _UnavailableTransferRepository();
      addTearDown(bestElevenRepository.dispose);
      addTearDown(injuryRepository.dispose);
      addTearDown(transferRepository.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: whitetheme,
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          body: OverviewTab(
            team: const TeamOverview(
              id: 68,
              name: 'Team 68',
              shortName: 'T68',
              imagePath: '',
            ),
            bestElevenRepository: bestElevenRepository,
            injuryRepository: injuryRepository,
            transferRepository: transferRepository,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final info = find.byKey(const ValueKey('best-xi-info'));
      final title =
          find.text(locale.languageCode == 'ko' ? '베스트 11' : 'BEST XI');
      await tester.ensureVisible(info);
      await tester.pumpAndSettle();
      expect(tester.getRect(info).left - tester.getRect(title).right, 4);
      await tester.tap(info);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('app-info-popup')), findsOneWidget);
      expect(
        find.text(locale.languageCode == 'ko'
            ? '이번 시즌 포지션별로 가장 많은 시간을 뛴 선수들을 보여줘요. 이 선수들이 팀에서 가장 자주 사용한 라인업을 이뤄요.'
            : "Shows the players who have played the most minutes in each position this season. Together they make up the team's most-used lineup."),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('omits unavailable overview sections and their headers',
      (tester) async {
    final bestElevenRepository = _EmptyBestElevenRepository();
    final injuryRepository = _UnavailableInjuryRepository();
    final transferRepository = _UnavailableTransferRepository();
    addTearDown(bestElevenRepository.dispose);
    addTearDown(injuryRepository.dispose);
    addTearDown(transferRepository.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: OverviewTab(
            team: const TeamOverview(
              id: 68,
              name: 'Team 68',
              shortName: 'T68',
              imagePath: '',
            ),
            bestElevenRepository: bestElevenRepository,
            injuryRepository: injuryRepository,
            transferRepository: transferRepository,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FIXTURE'), findsOneWidget);
    expect(find.text('BEST XI'), findsNothing);
    expect(find.text('STANDING'), findsNothing);
    expect(find.text('INJURY STATUS'), findsNothing);
    expect(find.text('TRANSFERS'), findsNothing);
    expect(find.byKey(const ValueKey('injury-error')), findsNothing);
    expect(find.byKey(const ValueKey('transfer-error')), findsNothing);
  });

  testWidgets('keeps OUT selected after the transfer section scrolls away',
      (tester) async {
    tester.view.physicalSize = const Size(393, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final bestElevenRepository = _EmptyBestElevenRepository();
    final injuryRepository = _UnavailableInjuryRepository();
    final transferRepository = _AvailableTransferRepository();
    addTearDown(bestElevenRepository.dispose);
    addTearDown(injuryRepository.dispose);
    addTearDown(transferRepository.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: whitetheme,
      home: Scaffold(
        body: OverviewTab(
          team: const TeamOverview(
            id: 68,
            name: 'Team 68',
            shortName: 'T68',
            imagePath: '',
          ),
          bestElevenRepository: bestElevenRepository,
          injuryRepository: injuryRepository,
          transferRepository: transferRepository,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-out-toggle')));
    await tester.pumpAndSettle();
    expect(find.text('Outgoing Player'), findsOneWidget);

    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();

    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(find.text('Outgoing Player'), findsOneWidget);
    expect(find.text('Incoming Player'), findsNothing);
  });
}

class _AvailableTransferRepository implements TransferRepository {
  late final TeamTransferWindow window = TeamTransferWindow(
    teamId: 68,
    windowKey: '2026 summer',
    incoming: const [
      TransferEntry(
        transferId: 1,
        playerId: 101,
        playerName: 'Incoming Player',
        direction: TransferDirection.incoming,
        typeId: 219,
      ),
    ],
    outgoing: const [
      TransferEntry(
        transferId: 2,
        playerId: 102,
        playerName: 'Outgoing Player',
        direction: TransferDirection.outgoing,
        typeId: 219,
      ),
    ],
  );
  final ValueNotifier<Map<int, TeamTransferWindow>> _cache =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows => _cache;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => window;

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) async => window;

  void dispose() => _cache.dispose();
}

class _EmptyBestElevenRepository implements BestElevenRepository {
  final ValueNotifier<Map<BestElevenQuery, TeamBestEleven>> _cache =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<BestElevenQuery, TeamBestEleven>> get cachedLineups =>
      _cache;

  @override
  TeamBestEleven? cachedForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) =>
      null;

  @override
  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) async =>
      null;

  void dispose() => _cache.dispose();
}

class _AvailableBestElevenRepository extends _EmptyBestElevenRepository {
  @override
  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) async =>
      TeamBestEleven(
        teamId: teamId,
        seasonId: 1,
        formation: '4-3-3',
        formations: const [],
        players: const [],
      );
}

class _UnavailableInjuryRepository implements TeamInjuryRepository {
  final ValueNotifier<Map<int, TeamInjuryReport>> _cache =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamInjuryReport>> get cachedReports => _cache;

  @override
  TeamInjuryReport? cachedForTeam(int teamId) => null;

  @override
  Future<TeamInjuryReport> loadForTeam(int teamId) =>
      Future<TeamInjuryReport>.error(
        TeamFeatureUnavailableException(
          teamId: teamId,
          feature: 'Injuries',
        ),
      );

  void dispose() => _cache.dispose();
}

class _UnavailableTransferRepository implements TransferRepository {
  final ValueNotifier<Map<int, TeamTransferWindow>> _cache =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows => _cache;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => null;

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) =>
      Future<TeamTransferWindow>.error(
        TeamFeatureUnavailableException(
          teamId: teamId,
          feature: 'Transfers',
        ),
      );

  void dispose() => _cache.dispose();
}
