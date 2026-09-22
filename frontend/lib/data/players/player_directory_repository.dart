import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';

typedef PlayerLeague = ({int id, String name, int available});
typedef PlayerRank = ({
  int id,
  String name,
  String? image,
  String? position,
  int rank,
  double score,
  double rating,
  int appearances
});
typedef PlayerWatch = ({
  int id,
  String name,
  String? image,
  double recent,
  double previous,
  double change
});

class PlayerRankingPage {
  const PlayerRankingPage(
      {required this.season,
      required this.leagues,
      required this.items,
      required this.total});
  final String? season;
  final List<PlayerLeague> leagues;
  final List<PlayerRank> items;
  final int total;
}

abstract interface class PlayerDirectoryRepository {
  Future<PlayerRankingPage> ranking(
      {int? league, String? position, int offset = 0});
  Future<List<PlayerWatch>> watch();
}

final PlayerDirectoryRepository playerDirectoryRepository =
    ApiPlayerDirectoryRepository();

class ApiPlayerDirectoryRepository implements PlayerDirectoryRepository {
  ApiPlayerDirectoryRepository({http.Client? client, this.config})
      : client = client ?? ApiConfig.sessionAwareClient();
  final http.Client client;
  final ApiConfig? config;
  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    final api = config ?? ApiConfig.unauthenticatedFromEnvironment();
    final uri = api.baseUri
        .resolve(path)
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await client.get(uri,
        headers: {'Accept': 'application/json', ...api.requestHeaders});
    if (response.statusCode != 200) {
      throw http.ClientException(
          'Could not load players (${response.statusCode})', uri);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  @override
  Future<PlayerRankingPage> ranking(
      {int? league, String? position, int offset = 0}) async {
    final json = await _get('players/ranking-current', {
      if (league != null) 'competition_id': '$league',
      if (position != null) 'position': position,
      'offset': '$offset',
      'limit': '100',
    });
    return PlayerRankingPage(
        season: json['season_name'] as String?,
        total: json['total'] as int,
        leagues: (json['leagues'] as List)
            .map((r) => (
                  id: r['competition_id'] as int,
                  name: r['name'] as String,
                  available: r['available_players'] as int
                ))
            .toList(),
        items: (json['items'] as List)
            .map((r) => (
                  id: r['player_id'] as int,
                  name: r['name'] as String,
                  image: r['image'] as String?,
                  position: r['position'] as String?,
                  rank: r['rank'] as int,
                  score: (r['display_score'] as num).toDouble(),
                  rating: (r['average_rating'] as num).toDouble(),
                  appearances: r['rated_matches'] as int
                ))
            .toList());
  }

  @override
  Future<List<PlayerWatch>> watch() async {
    final json = await _get('players/ones-to-watch', {});
    return (json['items'] as List)
        .map((r) => (
              id: r['player_id'] as int,
              name: r['name'] as String,
              image: r['image'] as String?,
              recent: (r['recent_average'] as num).toDouble(),
              previous: (r['previous_average'] as num).toDouble(),
              change: (r['change'] as num).toDouble()
            ))
        .toList();
  }
}
