import 'package:onetouch/data/match_analysis/api/api_match_analysis_response.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

MatchTacticalAnalysis matchAnalysisFromApiResponse(
  ApiMatchAnalysisResponse response,
) {
  return MatchTacticalAnalysis(
    fixtureId: response.fixtureId,
    available: response.available,
    home: _teamAnalysis(response.home),
    away: _teamAnalysis(response.away),
  );
}

MatchTeamTacticalAnalysis? _teamAnalysis(
  ApiMatchTeamAnalysisResponse? response,
) {
  if (response == null) return null;
  final defensive = response.defensiveActivity;
  return MatchTeamTacticalAnalysis(
    teamId: response.teamId,
    attack: MatchAttackMetrics(
      keyPasses: response.keyPasses,
      completedPassesIntoFinalThird: response.completedPassesIntoFinalThird,
    ),
    progression: MatchProgressionMetrics(
      completedPasses: response.completedPasses,
      progressivePasses: response.progressivePasses,
      channels: [
        for (final channel in response.channels)
          MatchProgressionChannel(
            channel: channel.channel,
            count: channel.count,
            percentage: channel.percentage,
          ),
      ],
    ),
    defensiveActivity: MatchDefensiveActivity(
      complete: defensive.complete,
      missingPositionCount: defensive.missingPositionCount,
      actionCount: defensive.actionCount,
      actions: [
        for (final point in defensive.actions)
          TacticalPitchPoint(x: point.x, y: point.y),
      ],
      recoveries: defensive.recoveries,
      highRegains: defensive.highRegains,
      ownHalfPercentage: defensive.ownHalfPercentage,
      opponentHalfPercentage: defensive.opponentHalfPercentage,
      averageRegainX: defensive.averageRegainX,
      averageRegainHeightMetres: defensive.averageRegainHeightMetres,
    ),
  );
}

MatchShotMap matchShotMapFromApiResponse(ApiMatchShotMapResponse response) {
  return MatchShotMap(
    fixtureId: response.fixtureId,
    available: response.available,
    homeCount: response.homeCount,
    awayCount: response.awayCount,
    shots: [
      for (final shot in response.shots)
        MatchShot(
          eventId: shot.eventId,
          teamId: shot.teamId,
          playerId: shot.playerId,
          playerName: shot.playerName,
          minute: shot.minute,
          extraMinute: shot.extraMinute,
          result: shot.result,
          start: TacticalPitchPoint(x: shot.start.x, y: shot.start.y),
          end: TacticalPitchPoint(x: shot.end.x, y: shot.end.y),
        ),
    ],
  );
}
