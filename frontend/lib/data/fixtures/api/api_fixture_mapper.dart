import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/models/fixture.dart';

Fixture fixtureFromApiResponse(ApiFixtureResponse response) {
  // Team display data remains TeamRepository-owned. Other response-only
  // metadata stays at the transport boundary until a domain feature needs it.
  return Fixture(
    fixtureId: response.fixtureId,
    seasonId: response.seasonId,
    competitionId: response.competitionId,
    homeTeamId: response.homeTeamId,
    awayTeamId: response.awayTeamId,
    competitionType: _competitionTypeFromApi(response.competitionType),
    roundName: response.roundName,
    stageId: response.stageId,
    groupId: response.groupId,
    status: _fixtureStatusFromApi(response.status),
    startingAt: _utcStartingAtFromApi(response.startingAt),
    homeScore: response.homeScore,
    awayScore: response.awayScore,
    homePenaltyScore: response.homePenaltyScore,
    awayPenaltyScore: response.awayPenaltyScore,
  );
}

String? _utcStartingAtFromApi(String? value) {
  if (value == null) return null;

  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  if (parsed.isUtc) return parsed.toIso8601String();

  // Sportmonks returns UTC by default, but the current 1Touch API serializes
  // its stored UTC DATETIME without an offset. Remove this compatibility path
  // once `starting_at` is always returned as offset-aware ISO 8601.
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  ).toIso8601String();
}

CompetitionType _competitionTypeFromApi(String value) {
  return switch (value) {
    'league' => CompetitionType.league,
    'europe' => CompetitionType.europe,
    'domestic_cup' => CompetitionType.cup,
    _ => throw FormatException(
        'Unsupported fixture competition_type "$value".',
      ),
  };
}

FixtureStatus _fixtureStatusFromApi(String? value) {
  return switch (value) {
    'past' => FixtureStatus.past,
    'live' => FixtureStatus.live,
    'upcoming' => FixtureStatus.upcoming,
    _ => FixtureStatus.unknown,
  };
}
