import 'package:onetouch/data/contracts/api/api_team_contract_response.dart';
import 'package:onetouch/models/team_contract_roster.dart';

TeamContractRoster teamContractRosterFromApiResponse(
  ApiTeamContractsResponse response,
) {
  return TeamContractRoster(
    teamId: response.teamId,
    seasonId: response.seasonId,
    players: response.players
        .map(
          (player) => TeamPlayerContract(
            playerId: player.playerId,
            playerName: player.playerName,
            playerImage: player.playerImage,
            jerseyNumber: player.jerseyNumber,
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
