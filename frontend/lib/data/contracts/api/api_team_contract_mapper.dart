import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/models/team_contract_roster.dart';

TeamContractRoster teamContractRosterFromApiResponse(
  ApiTeamContractsResponse response,
) {
  return TeamContractRoster(
    teamId: response.teamId,
    seasonId: response.seasonId,
    isCurrent: response.isCurrent,
    players: response.players
        .map(
          (player) => TeamPlayerContract(
            playerId: player.playerId,
            playerName: player.playerName,
            playerImage: player.playerImage,
            positionGroup: _positionGroupFromApi(player.positionGroupId),
            jerseyNumber: player.jerseyNumber,
            dateOfBirth: _dateFromApi(
              player.dateOfBirth,
              fieldName: 'date_of_birth',
            ),
            estimatedWeeklyGrossEur: player.estimatedWeeklyGrossEur,
            leadershipRole: _leadershipRoleFromApi(player.leadershipRole),
            startDate: _dateFromApi(
              player.startDate,
              fieldName: 'start_date',
            ),
            endDate: _dateFromApi(
              player.endDate,
              fieldName: 'end_date',
            ),
          ),
        )
        .toList(),
  );
}

TeamPositionGroup? _positionGroupFromApi(int? value) {
  if (value == null) return null;
  for (final group in TeamPositionGroup.values) {
    if (group.apiId == value) return group;
  }
  throw FormatException('Unrecognized position_group_id $value.');
}

TeamLeadershipRole? _leadershipRoleFromApi(String? value) {
  return switch (value) {
    null => null,
    'captain' => TeamLeadershipRole.captain,
    'vice_captain' => TeamLeadershipRole.viceCaptain,
    _ => throw FormatException('Unrecognized leadership_role "$value".'),
  };
}

DateTime? _dateFromApi(
  String? value, {
  required String fieldName,
}) {
  if (value == null) return null;

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid contract $fieldName "$value".');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid contract $fieldName "$value".');
  }
  return parsed;
}
