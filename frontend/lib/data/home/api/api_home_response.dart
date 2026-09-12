import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';

/// Transport model for `GET /v1/home`.
class ApiHomeResponse {
  ApiHomeResponse({
    required this.favoriteTeam,
    required List<ApiTeamResponse> followingTeams,
    required this.nextMatch,
    required this.lastMatch,
    required List<ApiFixtureResponse> calendar,
  })  : followingTeams = List.unmodifiable(followingTeams),
        calendar = List.unmodifiable(calendar);

  final ApiTeamResponse? favoriteTeam;
  final List<ApiTeamResponse> followingTeams;
  final ApiFixtureResponse? nextMatch;
  final ApiFixtureResponse? lastMatch;
  final List<ApiFixtureResponse> calendar;

  factory ApiHomeResponse.fromJson(Map<String, dynamic> json) {
    return ApiHomeResponse(
      favoriteTeam: _optionalObject(
        json,
        'favorite_team',
        ApiTeamResponse.fromJson,
      ),
      followingTeams: _objectList(
        json,
        'following_teams',
        ApiTeamResponse.fromJson,
      ),
      nextMatch: _optionalObject(
        json,
        'next_match',
        ApiFixtureResponse.fromJson,
      ),
      lastMatch: _optionalObject(
        json,
        'last_match',
        ApiFixtureResponse.fromJson,
      ),
      calendar: _objectList(
        json,
        'calendar',
        ApiFixtureResponse.fromJson,
      ),
    );
  }
}

T? _optionalObject<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable object field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is Map<String, dynamic>) return parse(value);
  throw FormatException('Expected nullable object field "$key".');
}

List<T> _objectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) {
    throw FormatException('Expected required list field "$key".');
  }
  return value.map((item) {
    if (item is! Map<String, dynamic>) {
      throw FormatException('Expected every "$key" entry to be a JSON object.');
    }
    return parse(item);
  }).toList(growable: false);
}
