import 'package:flutter/foundation.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/teams/mock/best_eleven_catalog.dart';
import 'package:onetouch/models/best_eleven.dart';
import 'package:onetouch/models/team_best_eleven.dart';

class MockBestElevenRepository implements BestElevenRepository {
  MockBestElevenRepository({List<BestElevenPlayer>? rows})
      : _rows = List.unmodifiable(rows ?? mockBestEleven);

  final List<BestElevenPlayer> _rows;
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

    final teamRows = _rows.where((row) => row.teamId == teamId).toList();
    if (teamRows.isEmpty) return null;

    final resolvedSeasonId = seasonId ?? teamRows.first.seasonId;
    final seasonRows =
        teamRows.where((row) => row.seasonId == resolvedSeasonId).toList();
    if (seasonRows.isEmpty) return null;

    final availableFormations = <String>[];
    for (final row in seasonRows) {
      if (!availableFormations.contains(row.formation)) {
        availableFormations.add(row.formation);
      }
    }

    final defaultFormation = availableFormations.first;
    final selectedFormation = query.formation ?? defaultFormation;
    if (!availableFormations.contains(selectedFormation)) return null;

    final selectedRows = seasonRows
        .where((row) => row.formation == selectedFormation)
        .toList()
      ..sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

    final lineup = TeamBestEleven(
      teamId: teamId,
      seasonId: resolvedSeasonId,
      formation: selectedFormation,
      formations: [
        for (final availableFormation in availableFormations)
          BestElevenFormationOption(
            formation: availableFormation,
            isDefault: availableFormation == defaultFormation,
          ),
      ],
      players: [
        for (final row in selectedRows)
          BestElevenEntry(
            slotKey: row.slotKey,
            slotIndex: row.slotIndex,
            playerId: row.playerId,
            playerName: row.playerName,
            playerImage: row.playerImage,
            positionName: row.positionName,
            detailedPositionName: row.detailedPositionName,
            starts: row.starts,
            totalMinutes: row.totalMinutes,
          ),
      ],
    );
    _cachedLineups.value = Map.unmodifiable({
      ..._cachedLineups.value,
      query: lineup,
    });
    return lineup;
  }
}
