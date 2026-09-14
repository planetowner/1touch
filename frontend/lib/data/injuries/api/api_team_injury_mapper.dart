import 'package:onetouch/data/injuries/api/api_team_injury_response.dart';
import 'package:onetouch/models/team_injury_report.dart';

TeamInjuryReport teamInjuryReportFromApiResponse(
  ApiTeamInjuriesResponse response,
) {
  return TeamInjuryReport(
    teamId: response.teamId,
    seasonId: response.seasonId,
    players: response.players
        .map(
          (player) => InjuredTeamPlayer(
            playerId: player.playerId,
            playerName: player.playerName,
            playerImage: player.playerImage,
            jerseyNumber: player.jerseyNumber,
            injuries: player.injuries
                .map(
                  (injury) => TeamPlayerInjury(
                    sidelineId: injury.sidelineId,
                    typeId: injury.typeId,
                    typeName: injury.typeName,
                    startDate: _dateFromApi(
                      injury.startDate,
                      fieldName: 'start_date',
                    ),
                    endDate: _dateFromApi(
                      injury.endDate,
                      fieldName: 'end_date',
                    ),
                  ),
                )
                .toList(),
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
    throw FormatException('Invalid injury $fieldName "$value".');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid injury $fieldName "$value".');
  }
  return parsed;
}
