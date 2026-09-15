import 'package:onetouch/data/players/api/api_player_club_history_response.dart';
import 'package:onetouch/models/player_club_history.dart';

PlayerClubHistory playerClubHistoryFromApiResponse(
  ApiPlayerClubHistoryResponse response,
) {
  return PlayerClubHistory(
    playerId: response.playerId,
    clubs: response.clubs
        .map(
          (club) => PlayerClubHistoryEntry(
            teamId: club.teamId,
            teamName: club.teamName,
            teamImage: _optionalHttpUri(
              club.teamImage,
              fieldName: 'team_image',
            ),
            startDate: _dateOnly(
              club.startDate,
              fieldName: 'start_date',
            ),
            endDate: _dateOnly(
              club.endDate,
              fieldName: 'end_date',
            ),
          ),
        )
        .toList(),
  );
}

DateTime? _dateOnly(String? value, {required String fieldName}) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw FormatException('Invalid club-history $fieldName "$value".');
  }

  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid club-history $fieldName "$value".');
  }
  return parsed;
}

String? _optionalHttpUri(String? value, {required String fieldName}) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    throw FormatException('Invalid club-history $fieldName "$value".');
  }
  return uri.toString();
}
