import 'package:onetouch/data/players/api/api_player_rankings_response.dart';
import 'package:onetouch/models/player_rankings.dart';

PlayerRankingsPage playerRankingsFromApiResponse(
  ApiPlayerRankingsResponse response,
) {
  if (response.competitionId < 1 || response.seasonId < 1) {
    throw const FormatException(
      'Expected positive competition and season IDs.',
    );
  }
  final seasonName = _nonEmpty(response.seasonName, 'season_name');
  if (response.method != 'fixed_historical_percentile') {
    throw FormatException(
      'Unknown player-ranking method "${response.method}".',
    );
  }
  if (response.total < 0 ||
      response.limit < 1 ||
      response.limit > 100 ||
      response.offset < 0 ||
      response.items.length > response.limit) {
    throw const FormatException('Invalid player-ranking pagination metadata.');
  }

  final reference = response.reference;
  if (reference.minimumRatedMatches < 1 || reference.sampleCount < 0) {
    throw const FormatException('Invalid player-ranking reference metadata.');
  }

  return PlayerRankingsPage(
    competitionId: response.competitionId,
    seasonId: response.seasonId,
    seasonName: seasonName,
    method: PlayerRankingMethod.fixedHistoricalPercentile,
    reference: PlayerRatingReference(
      startSeasonName: _nonEmpty(
        reference.startSeasonName,
        'reference.start_season_name',
      ),
      endSeasonName: _nonEmpty(
        reference.endSeasonName,
        'reference.end_season_name',
      ),
      minimumRatedMatches: reference.minimumRatedMatches,
      sampleCount: reference.sampleCount,
      frozenAt: _dateTime(reference.frozenAt, 'reference.frozen_at'),
    ),
    total: response.total,
    limit: response.limit,
    offset: response.offset,
    items: response.items.map(_rankedPlayerFromApiResponse).toList(),
  );
}

RankedPlayer _rankedPlayerFromApiResponse(ApiRankedPlayerResponse response) {
  if (response.rank < 1 ||
      response.playerId < 1 ||
      response.ratedMatches < 0 ||
      !response.averageRating.isFinite ||
      !response.percentileScore.isFinite ||
      !response.displayScore.isFinite ||
      response.percentileScore < 0 ||
      response.percentileScore > 100 ||
      response.displayScore < 0 ||
      response.displayScore > 100) {
    throw FormatException(
      'Invalid ranking values for player ${response.playerId}.',
    );
  }
  final image = response.playerImage?.trim();
  if (image != null && image.isEmpty) {
    throw const FormatException(
      'Expected player_image to be null or a non-empty string.',
    );
  }

  return RankedPlayer(
    rank: response.rank,
    playerId: response.playerId,
    playerName: _nonEmpty(response.playerName, 'items[].player_name'),
    playerImage: image,
    ratedMatches: response.ratedMatches,
    averageRating: response.averageRating,
    percentileScore: response.percentileScore,
    displayScore: response.displayScore,
    updatedAt: _dateTime(response.updatedAt, 'items[].updated_at'),
  );
}

String _nonEmpty(String value, String field) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('Expected non-empty string field "$field".');
  }
  return normalized;
}

DateTime _dateTime(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Expected ISO-8601 date-time field "$field".');
  }
  return parsed.toUtc();
}
