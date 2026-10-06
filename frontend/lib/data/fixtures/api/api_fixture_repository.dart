import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_detail_response.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';

/// 경기 목록과 상세를 같은 캐시에 보관해요.
/// 동기 조회는 이미 불러온 경기만 반환하므로 화면은 비동기 조회로 시작해요.
class ApiFixtureRepository implements FixtureRepository {
  ApiFixtureRepository({required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;

  // 라인업 지표 구성이 바뀌어 종료 경기의 7일 캐시도 새로 받아야 해요.
  static const _detailCacheSchemaVersion = 2;

  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final ValueNotifier<List<Fixture>> _fixtures = ValueNotifier(const []);
  final ValueNotifier<Map<TeamMatchesQuery, List<Fixture>>> _cachedTeamMatches =
      ValueNotifier(const {});
  final Map<TeamMatchesQuery, DateTime> _matchSavedAt = {};
  final Map<TeamMatchesQuery, Future<List<Fixture>>> _inFlightMatchLoads = {};
  final Map<TeamMatchesQuery, Future<List<Fixture>>> _inFlightMatchFetches = {};
  final ValueNotifier<Map<int, FixtureDetail>> _cachedDetails =
      ValueNotifier(const {});
  final Map<int, DateTime> _detailSavedAt = {};
  final Map<int, Future<FixtureDetail>> _inFlightDetailLoads = {};
  final Map<int, Future<FixtureDetail>> _inFlightDetailFetches = {};

  @override
  List<Fixture> get allFixtures => _fixtures.value;

  @override
  ValueListenable<List<Fixture>> get fixtures => _fixtures;

  @override
  ValueListenable<Map<TeamMatchesQuery, List<Fixture>>> get cachedTeamMatches =>
      _cachedTeamMatches;

  @override
  ValueListenable<Map<int, FixtureDetail>> get cachedDetails => _cachedDetails;

  @override
  FixtureDetail? cachedDetail(int fixtureId) => _cachedDetails.value[fixtureId];

  @override
  Fixture? findById(int fixtureId) => _fixtures.value
      .where((fixture) => fixture.fixtureId == fixtureId)
      .firstOrNull;

  @override
  Future<FixtureDetail> loadDetail(int fixtureId) {
    final cached = cachedDetail(fixtureId);
    if (cached != null) {
      _refreshDetailIfStale(fixtureId, cached.fixture.status);
      return Future.value(cached);
    }
    final inFlight = _inFlightDetailLoads[fixtureId];
    if (inFlight != null) return inFlight;
    late final Future<FixtureDetail> load;
    load = _restoreOrFetchDetail(fixtureId).whenComplete(() {
      if (identical(_inFlightDetailLoads[fixtureId], load)) {
        _inFlightDetailLoads.remove(fixtureId);
      }
    });
    _inFlightDetailLoads[fixtureId] = load;
    return load;
  }

  @override
  Future<FixtureDetail> refreshDetail(int fixtureId) => _fetchDetail(fixtureId);

  @override
  bool isRefreshingDetail(int fixtureId) =>
      _inFlightDetailFetches.containsKey(fixtureId);

  Future<FixtureDetail> _restoreOrFetchDetail(int fixtureId) async {
    final restored = await _restoreDetail(fixtureId);
    if (restored != null) {
      _refreshDetailIfStale(fixtureId, restored.fixture.status);
      return restored;
    }
    return _fetchDetail(fixtureId);
  }

  void _refreshDetailIfStale(int fixtureId, FixtureStatus status) {
    final tier = switch (status) {
      FixtureStatus.past => CacheTier.staticData,
      FixtureStatus.upcoming => CacheTier.standard,
      _ => CacheTier.realtime,
    };
    if (AppCachePolicy.shouldRefresh(
      tier: tier,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _detailSavedAt[fixtureId],
    )) {
      unawaited(
        _fetchDetail(fixtureId).then<void>((_) {}, onError: (Object _) {}),
      );
    }
  }

  Future<FixtureDetail?> _restoreDetail(int fixtureId) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = LocalCacheKeys.fixtureDetail(fixtureId);
    LocalCacheRecord? record;
    try {
      record = await store.read(key, schemaVersion: _detailCacheSchemaVersion);
    } on Object {
      return null;
    }
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final detail = _mapDetail(decoded, fixtureId);
      _publishDetail(fixtureId, detail, record.savedAt);
      return detail;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // A damaged cache must not block recovery from the API.
      }
      return null;
    }
  }

  Future<FixtureDetail> _fetchDetail(int fixtureId) {
    final inFlight = _inFlightDetailFetches[fixtureId];
    if (inFlight != null) return inFlight;
    late final Future<FixtureDetail> fetch;
    fetch = _fetchAndCacheDetail(fixtureId).whenComplete(() {
      if (identical(_inFlightDetailFetches[fixtureId], fetch)) {
        _inFlightDetailFetches.remove(fixtureId);
      }
    });
    _inFlightDetailFetches[fixtureId] = fetch;
    return fetch;
  }

  Future<FixtureDetail> _fetchAndCacheDetail(int fixtureId) async {
    final uri = _api.baseUri.resolve('fixtures/$fixtureId');
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final detail = _mapDetail(decoded, fixtureId);
    _publishDetail(fixtureId, detail, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(
        LocalCacheKeys.fixtureDetail(fixtureId),
        decoded,
        schemaVersion: _detailCacheSchemaVersion,
      );
    } on Object {
      // A storage failure should not hide a valid detail response.
    }
    return detail;
  }

  FixtureDetail _mapDetail(Map<String, dynamic> decoded, int fixtureId) {
    final response = ApiFixtureDetailResponse.fromJson(decoded);
    if (response.fixture.fixtureId != fixtureId) {
      throw FormatException(
        'Expected fixture_id $fixtureId but received '
        '${response.fixture.fixtureId}.',
      );
    }

    return fixtureDetailFromApiResponse(response);
  }

  void _publishDetail(int fixtureId, FixtureDetail detail, DateTime savedAt) {
    _detailSavedAt[fixtureId] = savedAt;
    _cachedDetails.value = Map.unmodifiable({
      ..._cachedDetails.value,
      fixtureId: detail,
    });
    _mergeIntoCache([detail.fixture]);
  }

  @override
  List<Fixture> forTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
  }) {
    return List.unmodifiable(
      _fixtures.value.where(
        (fixture) =>
            (fixture.homeTeamId == teamId || fixture.awayTeamId == teamId) &&
            _matchesFilters(
              fixture,
              seasonId: seasonId,
              competitionId: competitionId,
              status: status,
            ),
      ),
    );
  }

  @override
  Future<List<Fixture>> loadForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = _matchesQuery(teamId, status, start, end, limit, offset);
    final cached = _cachedTeamMatches.value[query];
    if (cached != null && status != null) {
      _refreshMatchesIfStale(query);
      return cached;
    }
    final inFlight = _inFlightMatchLoads[query];
    if (inFlight != null) return await inFlight;

    late final Future<List<Fixture>> load;
    load = _restoreOrFetchMatches(query).whenComplete(() {
      if (identical(_inFlightMatchLoads[query], load)) {
        _inFlightMatchLoads.remove(query);
      }
    });
    _inFlightMatchLoads[query] = load;
    return await load;
  }

  @override
  List<Fixture>? cachedForTeamMatches(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) =>
      _cachedTeamMatches
          .value[_matchesQuery(teamId, status, start, end, limit, offset)];

  @override
  Future<List<Fixture>> refreshForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) =>
      _fetchMatches(_matchesQuery(teamId, status, start, end, limit, offset));

  @override
  bool isRefreshingForTeam(
    int teamId, {
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit = 50,
    int offset = 0,
  }) =>
      _inFlightMatchFetches.containsKey(
        _matchesQuery(teamId, status, start, end, limit, offset),
      );

  TeamMatchesQuery _matchesQuery(
    int teamId,
    FixtureStatus? status,
    DateTime? start,
    DateTime? end,
    int limit,
    int offset,
  ) {
    if (status == FixtureStatus.unknown) {
      throw ArgumentError.value(
        status,
        'status',
        'must be past, live, upcoming, or null',
      );
    }
    if (limit < 1 || limit > 200) {
      throw RangeError.range(limit, 1, 200, 'limit');
    }
    if (offset < 0) {
      throw RangeError.range(offset, 0, null, 'offset');
    }

    return TeamMatchesQuery(
      teamId: teamId,
      status: status,
      start: start == null ? null : _formatDate(start),
      end: end == null ? null : _formatDate(end),
      limit: limit,
      offset: offset,
    );
  }

  Future<List<Fixture>> _restoreOrFetchMatches(TeamMatchesQuery query) async {
    if (query.status != null) {
      final restored = await _restoreMatches(query);
      if (restored != null) {
        _refreshMatchesIfStale(query);
        return restored;
      }
    }
    return _fetchMatches(query);
  }

  void _refreshMatchesIfStale(TeamMatchesQuery query) {
    final tier = switch (query.status) {
      FixtureStatus.past => CacheTier.staticData,
      FixtureStatus.upcoming => CacheTier.standard,
      FixtureStatus.live => CacheTier.realtime,
      _ => CacheTier.realtime,
    };
    if (AppCachePolicy.shouldRefresh(
      tier: tier,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _matchSavedAt[query],
    )) {
      unawaited(
          _fetchMatches(query).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<List<Fixture>?> _restoreMatches(TeamMatchesQuery query) async {
    final store = _cacheStore;
    if (store == null) return null;
    final key = _matchesKey(query);
    LocalCacheRecord? record;
    try {
      record = await store.read(key);
    } on Object {
      return null;
    }
    if (record == null) return null;
    try {
      final decoded = Map<String, dynamic>.from(record.payload as Map);
      final loaded = _mapMatches(decoded, query);
      _publishMatches(query, loaded, record.savedAt);
      return loaded;
    } on Object {
      try {
        await store.delete(key);
      } on Object {
        // Storage errors should not prevent a network fallback.
      }
      return null;
    }
  }

  Future<List<Fixture>> _fetchMatches(TeamMatchesQuery query) {
    final inFlight = _inFlightMatchFetches[query];
    if (inFlight != null) return inFlight;
    late final Future<List<Fixture>> fetch;
    fetch = _fetchAndCacheMatches(query).whenComplete(() {
      if (identical(_inFlightMatchFetches[query], fetch)) {
        _inFlightMatchFetches.remove(query);
      }
    });
    _inFlightMatchFetches[query] = fetch;
    return fetch;
  }

  Future<List<Fixture>> _fetchAndCacheMatches(TeamMatchesQuery query) async {
    final queryParameters = <String, String>{
      if (query.status != null) 'status': query.status!.name,
      if (query.start != null) 'start': query.start!,
      if (query.end != null) 'end': query.end!,
      'limit': '${query.limit}',
      'offset': '${query.offset}',
    };
    final uri = _api.baseUri.resolve('teams/${query.teamId}/matches').replace(
          queryParameters: queryParameters,
        );
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final loaded = _mapMatches(decoded, query);
    _publishMatches(query, loaded, DateTime.now().toUtc());
    if (query.status != null) {
      try {
        await _cacheStore?.write(_matchesKey(query), decoded);
      } on Object {
        // A storage failure should not hide a valid response.
      }
    }
    return loaded;
  }

  List<Fixture> _mapMatches(
    Map<String, dynamic> decoded,
    TeamMatchesQuery query,
  ) {
    final page = ApiTeamMatchesResponse.fromJson(decoded);
    if (page.limit != query.limit || page.offset != query.offset) {
      throw const FormatException('Unexpected team match page identity.');
    }
    return List<Fixture>.unmodifiable(
      page.items.map(fixtureFromApiResponse),
    );
  }

  void _publishMatches(
    TeamMatchesQuery query,
    List<Fixture> loaded,
    DateTime savedAt,
  ) {
    _matchSavedAt[query] = savedAt;
    _cachedTeamMatches.value = Map.unmodifiable({
      ..._cachedTeamMatches.value,
      query: loaded,
    });
    _mergeIntoCache(loaded);
  }

  String _matchesKey(TeamMatchesQuery query) => LocalCacheKeys.teamMatches(
        query.teamId,
        query.status!.name,
        query.start,
        query.end,
        query.limit,
        query.offset,
      );

  @override
  List<Fixture> forCompetition(
    int competitionId, {
    int? seasonId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  }) {
    return List.unmodifiable(
      _fixtures.value.where(
        (fixture) =>
            fixture.competitionId == competitionId &&
            _matchesFilters(
              fixture,
              seasonId: seasonId,
              status: status,
              competitionType: competitionType,
            ),
      ),
    );
  }

  @override
  Fixture? nextForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  }) {
    return forTeam(
      teamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.upcoming,
    ).where((fixture) => fixture.kickoff != null).firstOrNull;
  }

  @override
  Fixture? lastForTeam(
    int teamId, {
    int? seasonId,
    int? competitionId,
  }) {
    return forTeam(
      teamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.past,
    ).where((fixture) => fixture.kickoff != null).lastOrNull;
  }

  @override
  List<Fixture> headToHead(
    int firstTeamId,
    int secondTeamId, {
    int? seasonId,
    int? competitionId,
  }) {
    final matches = forTeam(
      firstTeamId,
      seasonId: seasonId,
      competitionId: competitionId,
      status: FixtureStatus.past,
    )
        .where(
          (fixture) =>
              fixture.homeTeamId == secondTeamId ||
              fixture.awayTeamId == secondTeamId,
        )
        .toList()
      ..sort((a, b) => _compareChronologically(a, b, descending: true));
    return List.unmodifiable(matches);
  }

  @override
  Future<List<Fixture>> loadHeadToHead(
    int fixtureId, {
    int limit = 10,
  }) async {
    if (limit < 1 || limit > 50) {
      throw RangeError.range(limit, 1, 50, 'limit');
    }

    final uri = _api.baseUri.resolve('fixtures/$fixtureId/head2head').replace(
      queryParameters: {'limit': '$limit'},
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(await _api.get(uri));
    final response = ApiFixtureHeadToHeadResponse.fromJson(decoded);
    if (response.fixtureId != fixtureId) {
      throw FormatException(
        'Expected fixture_id $fixtureId but received ${response.fixtureId}.',
      );
    }

    final loaded = List<Fixture>.unmodifiable(
      response.items.map(fixtureFromApiResponse),
    );
    _mergeIntoCache(loaded);
    return loaded;
  }

  @override
  Future<void> initialize() async {}

  void _mergeIntoCache(List<Fixture> loaded) {
    final byId = {
      for (final fixture in _fixtures.value) fixture.fixtureId: fixture,
      for (final fixture in loaded) fixture.fixtureId: fixture,
    };
    final merged = byId.values.toList()..sort(_compareChronologically);
    _fixtures.value = List.unmodifiable(merged);
  }

  static bool _matchesFilters(
    Fixture fixture, {
    int? seasonId,
    int? competitionId,
    FixtureStatus? status,
    CompetitionType? competitionType,
  }) {
    return (seasonId == null || fixture.seasonId == seasonId) &&
        (competitionId == null || fixture.competitionId == competitionId) &&
        (status == null || fixture.status == status) &&
        (competitionType == null || fixture.competitionType == competitionType);
  }

  static int _compareChronologically(
    Fixture a,
    Fixture b, {
    bool descending = false,
  }) {
    final aKickoff = a.kickoff;
    final bKickoff = b.kickoff;
    if (aKickoff == null || bKickoff == null) {
      if (aKickoff == null && bKickoff == null) {
        return a.fixtureId.compareTo(b.fixtureId);
      }
      return aKickoff == null ? 1 : -1;
    }

    final dateComparison = descending
        ? bKickoff.compareTo(aKickoff)
        : aKickoff.compareTo(bKickoff);
    if (dateComparison != 0) return dateComparison;
    return descending
        ? b.fixtureId.compareTo(a.fixtureId)
        : a.fixtureId.compareTo(b.fixtureId);
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
