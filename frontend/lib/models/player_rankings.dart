import 'package:flutter/foundation.dart';

enum PlayerRankingMethod { fixedHistoricalPercentile }

@immutable
class PlayerRatingReference {
  const PlayerRatingReference({
    required this.startSeasonName,
    required this.endSeasonName,
    required this.minimumRatedMatches,
    required this.sampleCount,
    required this.frozenAt,
  });

  final String startSeasonName;
  final String endSeasonName;
  final int minimumRatedMatches;
  final int sampleCount;
  final DateTime frozenAt;
}

@immutable
class RankedPlayer {
  const RankedPlayer({
    required this.rank,
    required this.playerId,
    required this.playerName,
    required this.playerImage,
    required this.ratedMatches,
    required this.averageRating,
    required this.percentileScore,
    required this.displayScore,
    required this.updatedAt,
  });

  final int rank;
  final int playerId;
  final String playerName;
  final String? playerImage;
  final int ratedMatches;
  final double averageRating;
  final double percentileScore;
  final double displayScore;
  final DateTime updatedAt;
}

@immutable
class PlayerRankingsPage {
  PlayerRankingsPage({
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.method,
    required this.reference,
    required this.total,
    required this.limit,
    required this.offset,
    required List<RankedPlayer> items,
  }) : items = List.unmodifiable(items);

  final int competitionId;
  final int seasonId;
  final String seasonName;
  final PlayerRankingMethod method;
  final PlayerRatingReference reference;
  final int total;
  final int limit;
  final int offset;
  final List<RankedPlayer> items;
}
