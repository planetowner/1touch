import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';

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
    ApiPlayerDirectoryRepository(api: apiClient);

class ApiPlayerDirectoryRepository implements PlayerDirectoryRepository {
  ApiPlayerDirectoryRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;
  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> params) async {
    final uri = _api.baseUri
        .resolve(path)
        .replace(queryParameters: params.isEmpty ? null : params);
    final response = await _api.get(uri);
    return _api.decodeJson<Map<String, dynamic>>(response);
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
