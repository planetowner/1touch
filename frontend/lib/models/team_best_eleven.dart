import 'package:flutter/foundation.dart';

String? _normalizeFormation(String? formation) {
  final normalized = formation?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

@immutable
class BestElevenQuery {
  BestElevenQuery({
    required this.teamId,
    this.seasonId,
    String? formation,
  }) : formation = _normalizeFormation(formation);

  final int teamId;
  final int? seasonId;
  final String? formation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BestElevenQuery &&
          teamId == other.teamId &&
          seasonId == other.seasonId &&
          formation == other.formation;

  @override
  int get hashCode => Object.hash(teamId, seasonId, formation);
}

@immutable
class BestElevenFormationOption {
  const BestElevenFormationOption({
    required this.formation,
    required this.isDefault,
    this.matchesUsed,
    this.totalValidMatches,
    this.usagePercentage,
  });

  final String formation;
  final int? matchesUsed;
  final int? totalValidMatches;
  final double? usagePercentage;
  final bool isDefault;
}

@immutable
class BestElevenEntry {
  const BestElevenEntry({
    required this.slotKey,
    required this.slotIndex,
    required this.playerId,
    required this.starts,
    required this.totalMinutes,
    this.playerName,
    this.playerImage,
    this.positionName,
    this.detailedPositionName,
  });

  final String slotKey;
  final int slotIndex;
  final int playerId;
  final String? playerName;
  final String? playerImage;
  final String? positionName;
  final String? detailedPositionName;
  final int starts;
  final int totalMinutes;
}

@immutable
class TeamBestEleven {
  TeamBestEleven({
    required this.teamId,
    required this.seasonId,
    required this.formation,
    required List<BestElevenFormationOption> formations,
    required List<BestElevenEntry> players,
    this.matchesUsed,
    this.totalValidMatches,
    this.usagePercentage,
  })  : formations = List.unmodifiable(formations),
        players = List.unmodifiable(players);

  final int teamId;
  final int? seasonId;
  final String formation;
  final int? matchesUsed;
  final int? totalValidMatches;
  final double? usagePercentage;
  final List<BestElevenFormationOption> formations;
  final List<BestElevenEntry> players;
}
