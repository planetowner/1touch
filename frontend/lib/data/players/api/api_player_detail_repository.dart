import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/players/api/api_player_detail_response.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/player_detail.dart';

class ApiPlayerDetailRepository implements CachedPlayerDetailRepository {
  ApiPlayerDetailRepository(
      {required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;
  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  static const _maxSnapshots = 24;
  final _snapshots = <(int, int?), PlayerDetailSnapshot>{};

  @override
  PlayerDetailSnapshot? snapshotFor(int playerId, {int? seasonId}) =>
      _snapshots[(playerId, seasonId)];

  @override
  Future<PlayerDetailSnapshot?> restoreFor(int playerId,
      {int? seasonId}) async {
    final memory = snapshotFor(playerId, seasonId: seasonId);
    if (memory != null) return memory;
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.playerDetail(playerId, seasonId);
    final record = await store.read(key);
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final detail = _mapDetail(decoded, playerId, seasonId);
      final snapshot = PlayerDetailSnapshot(detail, record.savedAt);
      _remember((playerId, seasonId), snapshot);
      return snapshot;
    } on Object {
      await store.delete(key);
      return null;
    }
  }

  Future<Map<String, dynamic>> _get(
      String path, Map<String, String> query) async {
    final uri = _api.baseUri
        .resolve(path)
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await _api.get(uri);
    return _api.decodeJson<Map<String, dynamic>>(response);
  }

  @override
  Future<PlayerDetail> load(int playerId, {int? seasonId}) async {
    final decoded = await _get('players/$playerId/detail', {
      if (seasonId != null) 'season_id': '$seasonId',
    });
    final detail = _mapDetail(decoded, playerId, seasonId);
    _remember((playerId, seasonId),
        PlayerDetailSnapshot(detail, DateTime.now().toUtc()));
    await _cacheStore?.write(
        LocalCacheKeys.playerDetail(playerId, seasonId), decoded);
    return detail;
  }

  PlayerDetail _mapDetail(
      Map<String, dynamic> decoded, int playerId, int? seasonId) {
    final detail = playerDetailFromJson(decoded);
    if (detail.playerId != playerId ||
        (seasonId != null && detail.selectedSeason?.id != seasonId)) {
      throw const FormatException('Player detail identity mismatch.');
    }
    return detail;
  }

  void _remember((int, int?) key, PlayerDetailSnapshot snapshot) {
    _snapshots.remove(key);
    _snapshots[key] = snapshot;
    if (_snapshots.length > _maxSnapshots) {
      _snapshots.remove(_snapshots.keys.first);
    }
  }

  @override
  Future<List<PlayerCandidate>> search(String query) async {
    final json = await _get('players/comparison-candidates', {'q': query});
    return (json['players'] as List)
        .cast<Map<String, dynamic>>()
        .map(playerCandidateFromJson)
        .toList();
  }

  @override
  Future<PlayerComparisonPage> comparisonCandidates(String query,
      {String? position,
      int? excludedId,
      int limit = 20,
      int offset = 0}) async {
    final json = await _get('players/comparison-candidates', {
      'q': query,
      if (position != null) 'position': position,
      if (excludedId != null) 'excluded_id': '$excludedId',
      'limit': '$limit',
      'offset': '$offset',
    });
    return PlayerComparisonPage(
      players: (json['players'] as List)
          .cast<Map<String, dynamic>>()
          .map((row) => PlayerComparisonCandidate(
                player: playerCandidateFromJson(row),
                position: row['position_group'] as String?,
                teamId: row['team_id'] as int?,
                teamName: row['team_name'] as String?,
                jerseyNumber: row['jersey_number'] as int?,
              ))
          .toList(),
      seasonName: json['season_name'] as String?,
      total: json['total'] as int,
      limit: json['limit'] as int,
      offset: json['offset'] as int,
    );
  }
}
