import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/competitions/competition_repository.dart';
import 'package:onetouch/data/seasons/season_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';
import 'package:onetouch/models/team_season_membership.dart';

class FootballCatalog implements TeamCompetitionContextResolver {
  FootballCatalog({ApiClient? api}) : _configuredApi = api;

  final ApiClient? _configuredApi;
  ApiClient get _api => _configuredApi ?? apiClient;
  final teams = ValueNotifier<List<Team>>(const []);
  final competitions = ValueNotifier<List<Competition>>(const []);
  final seasons = ValueNotifier<List<Season>>(const []);
  List<TeamSeasonMembership> memberships = const [];
  List<TeamSeasonMembership> _currentMemberships = const [];
  Map<int, TeamCompetitionContext> _teamContexts = const {};
  Future<void>? _request;
  bool isLoaded = false;

  // 화면마다 같은 목록을 요청하지 않고, 실패했을 때만 다시 읽어요.
  Future<void> initialize() => isLoaded ? Future.value() : _request ??= _load();

  Future<void> _load() async {
    try {
      final response = await _api.get(_api.baseUri.resolve('catalog'));
      final json = _api.decodeJson<Map<String, dynamic>>(response);
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

      // 목록 변경 알림을 받는 화면도 준비된 소속 정보를 조회할 수 있어야 해요.
      memberships = loadedMemberships;
      _currentMemberships = currentMemberships;
      _teamContexts = teamContexts;
      seasons.value = loadedSeasons;
      competitions.value = loadedCompetitions;
      teams.value = loadedTeams;
      isLoaded = true;
    } catch (_) {
      _request = null;
      rethrow;
    }
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
