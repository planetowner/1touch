import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/viewer_country_config.dart';
import 'package:onetouch/data/home/api/api_home_mapper.dart';
import 'package:onetouch/data/home/api/api_home_response.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/home_data.dart';

/// HTTP implementation of the verified `GET /v1/home` contract.
class ApiHomeRepository implements HomeSnapshotRepository {
  ApiHomeRepository({
    required ApiClient api,
    required String viewerCountry,
    LocalCacheStore? cacheStore,
  })  : _api = api,
        _cacheStore = cacheStore,
        _viewerCountry = ViewerCountryConfig.normalize(viewerCountry);

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final String _viewerCountry;
  static const _maxSnapshots = 24;
  final _snapshots = <(int, int, int), HomeSnapshot>{};
  int _cacheGeneration = 0;

  @override
  HomeSnapshot? snapshotFor({required int teamId, required DateTime month}) =>
      _snapshots[(teamId, month.year, month.month)];

  @override
  Future<HomeSnapshot?> restoreFor({
    required int teamId,
    required DateTime month,
  }) async {
    final memory = snapshotFor(teamId: teamId, month: month);
    if (memory != null) return memory;
    final store = _cacheStore;
    if (store == null) return null;
    final generation = _cacheGeneration;
    final key = LocalCacheKeys.home(teamId, month, _viewerCountry);
    final record = await store.read(
      key,
      scope: LocalCacheScopes.authenticatedUser,
    );
    if (record == null || generation != _cacheGeneration) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final data = _mapResponse(decoded, teamId: teamId);
      if (generation != _cacheGeneration) return null;
      final snapshot = HomeSnapshot(data, record.savedAt);
      _remember((teamId, month.year, month.month), snapshot);
      return snapshot;
    } on Object {
      await store.delete(key, scope: LocalCacheScopes.authenticatedUser);
      return null;
    }
  }

  @override
  void clearSnapshots() {
    _cacheGeneration++;
    _snapshots.clear();
  }

  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) async {
    final cacheGeneration = _cacheGeneration;
    const boundaryEnvelope = Duration(days: 1);
    final queryParameters = <String, String>{
      'viewer_country': _viewerCountry,
      if (teamId != null) 'team_id': '$teamId',
      // The backend filters UTC database dates while Home displays device-local
      // dates. Include adjacent UTC dates so timezone-boundary fixtures are not
      // omitted; FixtureCalendar performs the final local-month filtering.
      if (start != null)
        'start': _formatDate(_dateOnly(start).subtract(boundaryEnvelope)),
      if (end != null) 'end': _formatDate(_dateOnly(end).add(boundaryEnvelope)),
    };
    final homeUri = _api.baseUri.resolve('home');
    final uri = queryParameters.isEmpty
        ? homeUri
        : homeUri.replace(queryParameters: queryParameters);
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final data = _mapResponse(decoded, teamId: teamId);
    if (cacheGeneration == _cacheGeneration &&
        teamId != null &&
        start != null &&
        end != null &&
        start.year == end.year &&
        start.month == end.month) {
      final key = (teamId, start.year, start.month);
      _remember(key, HomeSnapshot(data, DateTime.now().toUtc()));
      await _cacheStore?.write(
        LocalCacheKeys.home(teamId, start, _viewerCountry),
        decoded,
        scope: LocalCacheScopes.authenticatedUser,
      );
    }
    return data;
  }

  HomeData _mapResponse(Map<String, dynamic> decoded, {int? teamId}) {
    final apiResponse = ApiHomeResponse.fromJson(decoded);
    final responseCountry = apiResponse.highlights?.viewerCountry;
    if (responseCountry != null && responseCountry != _viewerCountry) {
      throw FormatException(
        'Expected highlight viewer_country $_viewerCountry but received '
        '$responseCountry.',
      );
    }
    final data = homeDataFromApiResponse(apiResponse);
    if (teamId != null && data.favoriteTeam.teamId != teamId) {
      throw FormatException(
        'Expected Home team_id $teamId but received '
        '${data.favoriteTeam.teamId}.',
      );
    }
    return data;
  }

  void _remember((int, int, int) key, HomeSnapshot snapshot) {
    _snapshots.remove(key);
    _snapshots[key] = snapshot;
    if (_snapshots.length > _maxSnapshots) {
      _snapshots.remove(_snapshots.keys.first);
    }
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
