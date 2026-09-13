import 'package:onetouch/data/current_form/api/api_current_form_response.dart';
import 'package:onetouch/models/current_form.dart';

List<CurrentFormOption> currentFormOptionsFromApiResponse(
  ApiCurrentFormOptionsResponse response,
) {
  return List.unmodifiable(
    response.items.map(
      (item) => CurrentFormOption(
        teamId: item.teamId,
        teamName: item.teamName,
        teamShortCode: item.teamShortCode,
        teamLogo: item.teamLogo,
        leagueId: item.competitionId,
        seasonId: item.seasonId,
        seasonName: item.seasonName,
        roundsAvailable: item.roundsAvailable,
        latestRound: item.latestRound,
      ),
    ),
  );
}

CurrentFormComparison currentFormComparisonFromApiResponse(
  ApiCurrentFormResponse response,
) {
  return CurrentFormComparison(
    current: _seriesFromApiResponse(response.current),
    comparison: _seriesFromApiResponse(response.comparison),
    maxRound: response.maxRound,
    maxPoints: response.maxPoints,
  );
}

CurrentFormSeries _seriesFromApiResponse(
  ApiCurrentFormSeriesResponse response,
) {
  return CurrentFormSeries(
    teamId: response.teamId,
    teamName: response.teamName,
    teamShortCode: response.teamShortCode,
    teamLogo: response.teamLogo,
    leagueId: response.competitionId,
    seasonId: response.seasonId,
    seasonName: response.seasonName,
    isCurrent: response.isCurrent,
    points: response.points
        .map(
          (point) => CurrentFormPoint(
            roundNo: point.roundNo,
            matchDate: _utcDateTimeFromApi(point.matchDate),
            cumulativePoints: point.cumulativePoints,
          ),
        )
        .toList(),
  );
}

DateTime? _utcDateTimeFromApi(String? value) {
  if (value == null) return null;

  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid Current Form match_date "$value".');
  }
  if (parsed.isUtc) return parsed;

  // `match_date` originates from the fixtures UTC DATETIME column, but the
  // backend currently serializes it without an offset.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}
