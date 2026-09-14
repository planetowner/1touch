import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/teams/api/api_team_response.dart';

class ApiTeamOverviewResponse {
  const ApiTeamOverviewResponse({
    required this.team,
    required this.nextMatch,
    required this.lastMatch,
    required this.standing,
  });

  final ApiTeamResponse team;
  final ApiFixtureResponse? nextMatch;
  final ApiFixtureResponse? lastMatch;
  final ApiTeamOverviewStandingResponse? standing;

  factory ApiTeamOverviewResponse.fromJson(Map<String, dynamic> json) {
    return ApiTeamOverviewResponse(
      team: _requiredObject(json, 'team', ApiTeamResponse.fromJson),
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
      standing: _optionalObject(
        json,
        'standing',
        ApiTeamOverviewStandingResponse.fromJson,
      ),
    );
  }
}

class ApiTeamOverviewStandingResponse {
  ApiTeamOverviewStandingResponse({
    required this.position,
    required this.rankDelta,
    required this.teamId,
    required this.teamName,
    required this.teamLogo,
    required this.matchesPlayed,
    required this.won,
    required this.draw,
    required this.lost,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required List<String> lastFiveForm,
  }) : lastFiveForm = List.unmodifiable(lastFiveForm);

  final int position;
  final int? rankDelta;
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int matchesPlayed;
  final int won;
  final int draw;
  final int lost;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final List<String> lastFiveForm;

  factory ApiTeamOverviewStandingResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawForm = json['last5_form'];
    if (rawForm is! List || rawForm.any((value) => value is! String)) {
      throw const FormatException(
        'Expected required string list field "last5_form".',
      );
    }

    return ApiTeamOverviewStandingResponse(
      position: _requiredInt(json, 'position'),
      rankDelta: _optionalInt(json, 'rank_delta'),
      teamId: _requiredInt(json, 'team_id'),
      teamName: _requiredString(json, 'team_name'),
      teamLogo: _optionalString(json, 'team_logo'),
      matchesPlayed: _requiredInt(json, 'matches_played'),
      won: _requiredInt(json, 'won'),
      draw: _requiredInt(json, 'draw'),
      lost: _requiredInt(json, 'lost'),
      goalsFor: _requiredInt(json, 'goals_for'),
      goalsAgainst: _requiredInt(json, 'goals_against'),
      goalDiff: _requiredInt(json, 'goal_diff'),
      points: _requiredInt(json, 'points'),
      lastFiveForm: rawForm.cast<String>(),
    );
  }

  Map<String, dynamic> toDomainMap() {
    return Map.unmodifiable({
      'position': position,
      'rank_delta': rankDelta,
      'team_id': teamId,
      'team_name': teamName,
      'team_logo': teamLogo,
      'matches_played': matchesPlayed,
      'won': won,
      'draw': draw,
      'lost': lost,
      'goals_for': goalsFor,
      'goals_against': goalsAgainst,
      'goal_diff': goalDiff,
      'points': points,
      'last5_form': List<String>.unmodifiable(lastFiveForm),
    });
  }
}

T _requiredObject<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is Map<String, dynamic>) return parse(value);
  throw FormatException('Expected required object field "$key".');
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

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

int? _optionalInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable integer field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is int) return value;
  throw FormatException('Expected nullable integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Expected nullable string field "$key".');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected nullable string field "$key".');
}
