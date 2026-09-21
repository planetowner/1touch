import 'package:onetouch/data/fixtures/api/api_fixture_detail_response.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_mapper.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/player_club_history.dart';
import 'package:onetouch/models/player_detail.dart';

typedef _Json = Map<String, dynamic>;
List<_Json> _rows(_Json json, String key) => (json[key] as List).cast<_Json>();
double? _number(_Json json, String key) => (json[key] as num?)?.toDouble();
DateTime? _date(String? value) => value == null ? null : DateTime.parse(value);

FixturePlayerStatMetric playerMetricFromJson(Map<String, dynamic> json) {
  final item = ApiFixturePlayerStatMetricResponse.fromJson(json);
  return fixturePlayerMetricFromResponse(item);
}

PlayerSeasonMetric _metric(_Json json) => PlayerSeasonMetric(
    metric: playerMetricFromJson(json),
    per90: _number(json, 'per90'),
    rank: json['rank'] as int?,
    referenceCount: json['reference_count'] as int,
    percentile: _number(json, 'percentile'),
    observedMatches: json['observed_matches'] as int,
    totalMatches: json['total_matches'] as int);

PlayerRecord _record(_Json j) => (
      appearances: j['appearances'] as int,
      starts: j['starts'] as int,
      minutes: j['minutes'] as int,
      winRate: _number(j, 'win_rate'),
      rating: _number(j, 'rating')
    );
PlayerCompetitionRecord _competition(_Json j) => (
      id: j['competition_id'] as int,
      name: j['competition_name'] as String,
      record: _record(j)
    );
PlayerDetailSeason _season(_Json j) => (
      id: j['season_id'] as int,
      name: j['season_name'] as String,
      competitionId: j['competition_id'] as int,
      competitionName: j['competition_name'] as String
    );

PlayerDetail playerDetailFromJson(Map<String, dynamic> j) {
  final p = j['profile'] as _Json;
  final a = j['analysis'] as _Json?;
  return PlayerDetail(
      playerId: j['player_id'] as int,
      profile: (
        name: p['name'] as String,
        image: p['image'] as String?,
        teamId: p['team_id'] as int?,
        teamName: p['team_name'] as String?,
        teamImage: p['team_image'] as String?,
        jerseyNumber: p['jersey_number'] as int?,
        heightCm: p['height_cm'] as int?,
        weightKg: p['weight_kg'] as int?,
        birthDate: _date(p['date_of_birth'] as String?),
        nationality: p['nationality'] as String?,
        nationalityImage: p['nationality_image'] as String?,
        position: p['position_group'] as String?,
        squadRole: p['squad_role'] as String?
      ),
      currentSeason: j['current_season_name'] as String?,
      currentPosition: j['current_position'] as String?,
      seasons: _rows(j, 'seasons').map(_season).toList(),
      selectedSeason: j['selected_season'] == null
          ? null
          : _season(j['selected_season'] as _Json),
      competitions: _rows(j, 'competitions').map(_competition).toList(),
      matches: _rows(j, 'matches')
          .map((r) => PlayerDetailMatch(
              id: r['fixture_id'] as int,
              date: DateTime.parse('${r['starting_at']}Z'),
              live: ![5, 7, 8].contains(r['state_id']),
              competition: r['competition_name'] as String,
              round: r['round_name'] as String?,
              opponent: r['opponent_name'] as String?,
              opponentImage: r['opponent_image'] as String?,
              result: r['result'] as String?,
              homeScore: r['home_score'] as int?,
              awayScore: r['away_score'] as int?,
              rating: _number(r, 'rating'),
              metrics: _rows(r, 'metrics').map(playerMetricFromJson).toList()))
          .toList(),
      analysis: a == null
          ? null
          : PlayerAnalysis(
              position: a['position_group'] as String?,
              categories: _rows(a, 'categories')
                  .map((c) => (
                        code: c['code'] as String,
                        label: c['label'] as String,
                        metrics: _rows(c, 'metrics').map(_metric).toList()
                      ))
                  .toList(),
              topStats: _rows(a, 'top_stats').map(_metric).toList(),
              minimumMinutes: a['reference_minimum_minutes'] as int,
              referencePlayers: a['reference_players'] as int,
              startingRate: _number(a, 'starting_rate'),
              winRate: _number(a, 'win_rate'),
              starts: a['starts'] as int,
              teamMatches: a['team_matches'] as int,
              performance: _rows(a, 'performance')
                  .map((r) => (
                        fixtureId: r['fixture_id'] as int,
                        round: r['round'] as int,
                        rating: _number(r, 'rating')
                      ))
                  .toList()),
      career: _rows(j, 'career')
          .map((r) => (
                season: r['season_name'] as String,
                teamId: r['team_id'] as int,
                teamName: r['team_name'] as String,
                teamCode: r['team_code'] as String?,
                teamImage: r['team_image'] as String?,
                record: _record(r),
                competitions:
                    _rows(r, 'competitions').map(_competition).toList()
              ))
          .toList(),
      clubs: _rows(j, 'clubs')
          .map((r) => PlayerClubHistoryEntry(
              teamId: r['team_id'] as int,
              teamName: r['team_name'] as String?,
              teamImage: r['team_image'] as String?,
              startDate: _date(r['start_date'] as String?),
              endDate: _date(r['end_date'] as String?)))
          .toList(),
      honours: _rows(j, 'honours')
          .map((r) => (
                teamId: r['team_id'] as int,
                teamName: r['team_name'] as String?,
                teamImage: r['team_image'] as String?,
                competitionId: r['competition_id'] as int,
                competitionName: r['competition_name'] as String?,
                season: r['season_name'] as String?
              ))
          .toList());
}
