import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/models/team_best_eleven.dart';
import 'package:onetouch/models/team_injury_report.dart';
import 'package:onetouch/models/team_transfer_window.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Overview.dart';

void main() {
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
            team: const <String, dynamic>{
              'id': 68,
              'standing': null,
            },
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
