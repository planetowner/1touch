import 'package:onetouch/core/api_client.dart';

/// 원문은 색상·검색 등에 쓰이므로 번역은 ID로 찾아 화면에만 적용해요.
class FootballNames {
  const FootballNames({
    this.teams = const {},
    this.teamShortNames = const {},
    this.players = const {},
    this.playerShortNames = const {},
    this.competitions = const {},
  });

  factory FootballNames.fromJson(Map<String, dynamic> json) {
    Map<int, String> names(String key) => Map.unmodifiable(
          (json[key] as Map<String, dynamic>).map(
            (id, name) => MapEntry(int.parse(id), name as String),
          ),
        );
    return FootballNames(
      teams: names('teams'),
      teamShortNames: names('team_short_names'),
      players: names('players'),
      playerShortNames: names('player_short_names'),
      competitions: names('competitions'),
    );
  }

  final Map<int, String> teams,
      teamShortNames,
      players,
      playerShortNames,
      competitions;

  // 짧은 번역이 없는 팀·선수는 같은 언어의 일반 이름을 먼저 사용해요.
  String team(int? id, String original, {bool short = false}) =>
      (short ? teamShortNames[id] : null) ?? teams[id] ?? original;
  String player(int? id, String original, {bool short = false}) =>
      (short ? playerShortNames[id] : null) ?? players[id] ?? original;
  String competition(int? id, String original) => competitions[id] ?? original;
}

class FootballNamesRepository {
  FootballNamesRepository(this._client);
  final ApiClient _client;
  final Map<String, Future<FootballNames>> _requests = {};

  Future<FootballNames> load(String language) =>
      _requests.putIfAbsent(language, () => _fetch(language));

  Future<FootballNames> _fetch(String language) async {
    try {
      final response = await _client.get(
        _client.baseUri.resolve('football-names/$language/display'),
      );
      return FootballNames.fromJson(
        _client.decodeJson<Map<String, dynamic>>(response),
      );
    } catch (_) {
      _requests.remove(language);
      rethrow;
    }
  }
}
