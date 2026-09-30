import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/data/seasons/season_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/data/local/local_cache_store.dart';
import 'package:onetouch/models/team_season_membership.dart';

class FootballCatalog implements TeamCompetitionContextResolver {
  FootballCatalog({ApiClient? api, LocalCacheStore? cacheStore})
      : _configuredApi = api,
        _cacheStore = cacheStore;

  final ApiClient? _configuredApi;
  final LocalCacheStore? _cacheStore;
  ApiClient get _api => _configuredApi ?? apiClient;
  final teams = ValueNotifier<List<Team>>(const []);
  final competitions = ValueNotifier<List<Competition>>(const []);
  final seasons = ValueNotifier<List<Season>>(const []);
  List<TeamSeasonMembership> memberships = const [];
  List<TeamSeasonMembership> _currentMemberships = const [];
  Map<int, TeamCompetitionContext> _teamContexts = const {};
  Future<void>? _request;
  Future<void>? _refreshRequest;
  DateTime? _savedAt;
  bool isLoaded = false;
  DateTime? get savedAt => _savedAt;

  /// Hydrates the local source first. Static data is revalidated only when its
  /// centralized tier policy says it is stale.
  Future<void> initialize() =>
      isLoaded ? Future.value() : _request ??= _initialize();

  Future<void> _initialize() async {
    final store = _cacheStore;
    LocalCacheRecord? cached;
    if (store != null) {
      cached = await store.read(LocalCacheKeys.catalog);
      if (cached != null) {
        try {
          _applyJson((cached.payload as Map).cast<String, dynamic>());
          _savedAt = cached.savedAt;
        } on Object {
          await store.delete(LocalCacheKeys.catalog);
          cached = null;
        }
      }
    }

    if (!isLoaded) {
      await refresh(trigger: CacheSyncTrigger.bootstrap);
      return;
    }
    if (AppCachePolicy.shouldRefresh(
      tier: CacheTier.staticData,
      trigger: CacheSyncTrigger.bootstrap,
      savedAt: _savedAt,
    )) {
      unawaited(_refreshInBackground(CacheSyncTrigger.bootstrap));
    }
  }

  Future<void> _refreshInBackground(CacheSyncTrigger trigger) async {
    try {
      await refresh(trigger: trigger);
    } on Object {
      // Stale local data remains available when revalidation fails.
    }
  }

  Future<void> refresh({
    CacheSyncTrigger trigger = CacheSyncTrigger.userRefresh,
  }) {
    if (!AppCachePolicy.shouldRefresh(
      tier: CacheTier.staticData,
      trigger: trigger,
      savedAt: _savedAt,
    )) {
      return Future.value();
    }
    return _refreshRequest ??= _loadFromNetwork().whenComplete(() {
      _refreshRequest = null;
    });
  }

  Future<void> _loadFromNetwork() async {
    try {
      final response = await _api.get(_api.baseUri.resolve('catalog'));
      final json = _api.decodeJson<Map<String, dynamic>>(response);
      final snapshot = _parseJson(json);
      // The local database is the source of truth: validate, persist, then
      // publish the same snapshot to listeners.
      await _cacheStore?.write(LocalCacheKeys.catalog, json);
      _savedAt = DateTime.now().toUtc();
      _applySnapshot(snapshot);
    } catch (_) {
      if (!isLoaded) _request = null;
      rethrow;
    }
  }

  void _applyJson(Map<String, dynamic> json) =>
      _applySnapshot(_parseJson(json));

  _CatalogSnapshot _parseJson(Map<String, dynamic> json) {
    final loadedTeams = _rows(json, 'teams', teamFromApiJson);
    final loadedCompetitions =
        _rows(json, 'competitions', Competition.fromJson);
    final loadedSeasons = _rows(json, 'seasons', Season.fromJson);
    final loadedMemberships =
        _rows(json, 'memberships', TeamSeasonMembership.fromJson);

    // 팀 편집 창이 멈추지 않도록 현재 소속을 한 번 계산해 함께 사용해요.
    final currentSeasonIds = {
      for (final season in loadedSeasons)
        if (season.isCurrent) season.seasonId,
    };
    final currentMemberships = loadedMemberships
        .where((membership) => currentSeasonIds.contains(membership.seasonId))
        .toList(growable: false);
    final teamContexts = <int, TeamCompetitionContext>{};
    for (final membership in currentMemberships) {
      if (!TeamPageEligibility.domesticBigFiveCompetitionIds
          .contains(membership.competitionId)) {
        continue;
      }
      // 기존 조회처럼 응답에서 먼저 나온 현재 리그 소속을 사용해요.
      teamContexts.putIfAbsent(
        membership.teamId,
        () => TeamCompetitionContext(
          teamId: membership.teamId,
          seasonId: membership.seasonId,
          competitionId: membership.competitionId,
          competitionName: loadedCompetitions
              .where((c) => c.competitionId == membership.competitionId)
              .firstOrNull
              ?.name,
        ),
      );
    }

    return _CatalogSnapshot(
      teams: loadedTeams,
      competitions: loadedCompetitions,
      seasons: loadedSeasons,
      memberships: loadedMemberships,
      currentMemberships: currentMemberships,
      teamContexts: teamContexts,
    );
  }

  void _applySnapshot(_CatalogSnapshot snapshot) {
    // 목록 변경 알림을 받는 화면도 준비된 소속 정보를 조회할 수 있어야 해요.
    memberships = snapshot.memberships;
    _currentMemberships = snapshot.currentMemberships;
    _teamContexts = snapshot.teamContexts;
    seasons.value = snapshot.seasons;
    competitions.value = snapshot.competitions;
    teams.value = snapshot.teams;
    isLoaded = true;
  }

  List<T> _rows<T>(Map<String, dynamic> json, String key,
          T Function(Map<String, dynamic>) parse) =>
      List.unmodifiable(
          (json[key] as List).cast<Map<String, dynamic>>().map(parse));

  List<Team> currentTeams(int competitionId) {
    final ids = _currentMemberships
        .where((m) => m.competitionId == competitionId)
        .map((m) => m.teamId)
        .toSet();
    return teams.value.where((team) => ids.contains(team.teamId)).toList();
  }

  List<Competition> currentCompetitions(int teamId) {
    final ids = _currentMemberships
        .where((m) => m.teamId == teamId)
        .map((m) => m.competitionId)
        .toSet();
    return competitions.value
        .where((c) => ids.contains(c.competitionId))
        .toList();
  }

  @override
  TeamCompetitionContext? resolve(int teamId) => _teamContexts[teamId];
}

class _CatalogSnapshot {
  const _CatalogSnapshot({
    required this.teams,
    required this.competitions,
    required this.seasons,
    required this.memberships,
    required this.currentMemberships,
    required this.teamContexts,
  });

  final List<Team> teams;
  final List<Competition> competitions;
  final List<Season> seasons;
  final List<TeamSeasonMembership> memberships;
  final List<TeamSeasonMembership> currentMemberships;
  final Map<int, TeamCompetitionContext> teamContexts;
}

class CatalogTeamRepository implements TeamRepository {
  CatalogTeamRepository(this.catalog);
  final FootballCatalog catalog;
  @override
  List<Team> get allTeams => catalog.teams.value;
  @override
  ValueListenable<List<Team>> get teams => catalog.teams;
  @override
  Team? findById(int id) =>
      allTeams.where((team) => team.teamId == id).firstOrNull;
  @override
  bool contains(int id) => findById(id) != null;
  @override
  Future<void> initialize() => catalog.initialize();
  @override
  List<Team> search(String query) {
    final value = query.trim().toLowerCase();
    return allTeams
        .where((team) =>
            '${team.name} ${team.shortName ?? ''} ${team.shortCode ?? ''}'
                .toLowerCase()
                .contains(value))
        .toList();
  }
}

class CatalogCompetitionRepository implements CompetitionRepository {
  CatalogCompetitionRepository(this.catalog);
  final FootballCatalog catalog;
  @override
  List<Competition> get allCompetitions => catalog.competitions.value;
  @override
  ValueListenable<List<Competition>> get competitions => catalog.competitions;
  @override
  Competition? findById(int id) =>
      allCompetitions.where((c) => c.competitionId == id).firstOrNull;
  @override
  bool contains(int id) => findById(id) != null;
  @override
  List<Competition> get domesticCompetitions => allCompetitions
      .where((c) => TeamPageEligibility.domesticBigFiveCompetitionIds
          .contains(c.competitionId))
      .toList();
  @override
  Future<void> initialize() => catalog.initialize();
}

class CatalogSeasonRepository implements SeasonRepository {
  CatalogSeasonRepository(this.catalog);
  final FootballCatalog catalog;
  @override
  List<Season> get allSeasons => catalog.seasons.value;
  @override
  ValueListenable<List<Season>> get seasons => catalog.seasons;
  @override
  Season? findById(int id) =>
      allSeasons.where((s) => s.seasonId == id).firstOrNull;
  @override
  bool contains(int id) => findById(id) != null;
  @override
  List<Season> forCompetition(int id) =>
      allSeasons.where((s) => s.competitionId == id).toList();
  @override
  Season? currentForCompetition(int id) =>
      forCompetition(id).where((s) => s.isCurrent).firstOrNull;
  @override
  Future<void> initialize() => catalog.initialize();
}
