import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

typedef BracketSlot = ({int? teamId, String label, String? sourceTieId});
typedef BracketMatch = ({
  int id,
  bool detailAvailable,
  String status,
  int? homeScore,
  int? awayScore
});
typedef BracketTie = ({
  String id,
  String? nextTieId,
  List<BracketSlot> slots,
  List<int>? aggregateScore,
  int? winnerTeamId,
  List<BracketMatch> matches
});
typedef BracketStage = ({String name, List<BracketTie> ties});

class TournamentBracket {
  const TournamentBracket({required this.status, required this.stages});
  final String status;
  final List<BracketStage> stages;

  factory TournamentBracket.fromJson(Map<String, dynamic> json) {
    final stages = (json['stages'] as List)
        .map((stage) => (
              name: stage['name'] as String,
              ties: (stage['ties'] as List)
                  .map((tie) => (
                        id: tie['tie_id'] as String,
                        nextTieId: tie['next_tie_id'] as String?,
                        slots: (tie['slots'] as List)
                            .map((slot) => (
                                  teamId: slot['team_id'] as int?,
                                  label: slot['label'] as String,
                                  sourceTieId: slot['source_tie_id'] as String?,
                                ))
                            .toList(),
                        aggregateScore:
                            (tie['aggregate_score'] as List?)?.cast<int>(),
                        winnerTeamId: tie['winner_team_id'] as int?,
                        matches: (tie['fixtures'] as List)
                            .map((match) => (
                                  id: match['fixture_id'] as int,
                                  detailAvailable:
                                      match['detail_available'] as bool,
                                  status: match['state'] as String,
                                  homeScore: match['home_score'] as int?,
                                  awayScore: match['away_score'] as int?,
                                ))
                            .toList(),
                      ))
                  .toList(),
            ))
        .toList();
    // API의 경기 ID 순서는 대진 경로와 달라요. 다음 대진 순서에 맞춰 앞 라운드를 묶어요.
    for (var index = stages.length - 2; index >= 0; index--) {
      final ties = stages[index].ties;
      final following = stages[index + 1].ties;
      final destinations = {
        for (var i = 0; i < following.length; i++) following[i].id: i,
      };
      final original = {for (var i = 0; i < ties.length; i++) ties[i].id: i};
      ties.sort((a, b) {
        final byDestination = (destinations[a.nextTieId] ?? following.length)
            .compareTo(destinations[b.nextTieId] ?? following.length);
        return byDestination != 0
            ? byDestination
            : original[a.id]!.compareTo(original[b.id]!);
      });
    }
    return TournamentBracket(status: json['status'] as String, stages: stages);
  }
}

class TournamentBracketRepository extends ChangeNotifier {
  TournamentBracketRepository(
      {required ApiClient api, LocalCacheStore? cacheStore})
      : _api = api,
        _cacheStore = cacheStore;
  final ApiClient _api;
  final LocalCacheStore? _cacheStore;
  final _cached = <(int, int), TournamentBracket>{};
  final _savedAt = <(int, int), DateTime>{};
  final _loads = <(int, int), Future<TournamentBracket>>{};
  final _fetches = <(int, int), Future<TournamentBracket>>{};
  static const supportedCompetitions = {2, 5, 2286, 24, 27, 390, 570};

  TournamentBracket? cached(int competitionId, int seasonId) =>
      _cached[(competitionId, seasonId)];

  Future<TournamentBracket> load(int competitionId, int seasonId) {
    final query = (competitionId, seasonId);
    final bracket = _cached[query];
    if (bracket != null) {
      _refreshIfStale(query);
      return Future.value(bracket);
    }
    return _loads.putIfAbsent(
        query,
        () => _restoreOrFetch(query).whenComplete(() {
              _loads.remove(query);
            }));
  }

  Future<TournamentBracket> refresh(int competitionId, int seasonId) =>
      _fetch((competitionId, seasonId));

  Future<TournamentBracket> _restoreOrFetch((int, int) query) async {
    LocalCacheRecord? record;
    try {
      record = await _cacheStore
          ?.read(LocalCacheKeys.tournamentBracket(query.$1, query.$2));
      if (record != null && !_cached.containsKey(query)) {
        final bracket = _mapAndVerify(
            Map<String, dynamic>.from(record.payload as Map), query);
        _publish(query, bracket, record.savedAt);
      }
    } on Object {
      // 저장소를 읽지 못해도 서버에서 대진표를 가져올 수 있어요.
    }
    final bracket = _cached[query];
    if (bracket == null) return _fetch(query);
    _refreshIfStale(query);
    return bracket;
  }

  void _refreshIfStale((int, int) query) {
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.shortLived,
      trigger: CacheSyncTrigger.screenEnter,
      savedAt: _savedAt[query],
    )) {
      unawaited(_fetch(query).then<void>((_) {}, onError: (Object _) {}));
    }
  }

  Future<TournamentBracket> _fetch((int, int) query) => _fetches.putIfAbsent(
      query,
      () => _fetchAndCache(query).whenComplete(() {
            _fetches.remove(query);
          }));

  Future<TournamentBracket> _fetchAndCache((int, int) query) async {
    final (competitionId, seasonId) = query;
    final response = await _api.get(_api.baseUri
        .resolve('competitions/$competitionId/bracket')
        .replace(queryParameters: {'season_id': '$seasonId'}));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    final bracket = _mapAndVerify(json, query);
    _publish(query, bracket, DateTime.now().toUtc());
    try {
      await _cacheStore?.write(
          LocalCacheKeys.tournamentBracket(competitionId, seasonId), json);
    } on Object {
      // 저장 실패 때문에 이미 받은 대진표를 숨기지 않아요.
    }
    return bracket;
  }

  TournamentBracket _mapAndVerify(Map<String, dynamic> json, (int, int) query) {
    if (json['competition_id'] != query.$1 || json['season_id'] != query.$2) {
      throw const FormatException('Bracket identity mismatch.');
    }
    return TournamentBracket.fromJson(json);
  }

  void _publish((int, int) query, TournamentBracket bracket, DateTime savedAt) {
    _cached[query] = bracket;
    _savedAt[query] = savedAt;
    notifyListeners();
  }
}

final tournamentBracketRepository =
    TournamentBracketRepository(api: apiClient, cacheStore: localCacheStore);
