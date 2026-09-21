import 'package:onetouch/data/best_eleven/api/api_best_eleven_response.dart';
import 'package:onetouch/models/team_best_eleven.dart';

TeamBestEleven teamBestElevenFromApiResponse(ApiBestElevenResponse response) {
  return TeamBestEleven(
    teamId: response.teamId,
    seasonId: response.seasonId,
    formation: response.formation,
    matchesUsed: response.matchesUsed,
    totalValidMatches: response.totalValidMatches,
    usagePercentage: response.usagePercentage,
    formations: response.formations
        .map(
          (formation) => BestElevenFormationOption(
            formation: formation.formation,
            matchesUsed: formation.matchesUsed,
            totalValidMatches: formation.totalValidMatches,
            usagePercentage: formation.usagePercentage,
            isDefault: formation.isDefault,
          ),
        )
        .toList(),
    players: response.players
        .map(
          (player) => BestElevenEntry(
            slotKey: player.slotKey,
            slotIndex: player.slotIndex,
            playerId: player.playerId,
            playerName: player.playerName,
            playerImage: player.playerImage,
            jerseyNumber: player.jerseyNumber,
            positionGroupCode: player.positionGroupCode,
            positionCode: player.positionCode,
            starts: player.starts,
          ),
        )
        .toList(),
  );
}
