import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/data/search/search_repository.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';

String fixture(String name) =>
    File('test/fixtures/$name.json').readAsStringSync();

ApiClient api(Future<http.Response> Function(http.Request) respond) =>
    ApiClient(
        client: MockClient(respond),
        baseUri: Uri.parse('https://example.com/v1/'),
        requestHeaders: () => {'Authorization': 'Bearer current-session'});

void main() {
  test(
      'one catalog request supplies team, competition and current season selectors',
      () async {
    var requests = 0;
    final gate = Completer<http.Response>();
    final catalog = FootballCatalog(api: api((request) async {
      requests++;
      expect(request.url.path, '/v1/catalog');
      expect(request.headers['Authorization'], 'Bearer current-session');
      return gate.future;
    }));
    final teams = CatalogTeamRepository(catalog);
    final competitions = CatalogCompetitionRepository(catalog);
    final seasons = CatalogSeasonRepository(catalog);
    final notifiedSeasonIds = <int?>[];
    catalog.seasons.addListener(() {
      notifiedSeasonIds.add(catalog.resolve(8)?.seasonId);
    });
    final pending = Future.wait(
        [teams.initialize(), competitions.initialize(), seasons.initialize()]);
    gate.complete(http.Response(fixture('api_catalog'), 200));
    await pending;
    expect(requests, 1);
    expect(teams.findById(8)?.name, 'Example United');
    expect(competitions.domesticCompetitions.single.competitionId, 8);
    expect(competitions.findById(2)?.shortCode, 'UCL');
    expect(seasons.currentForCompetition(8)?.seasonId, 28083);
    expect(seasons.currentForCompetition(8)?.startingAt, isNull);
    expect(catalog.currentTeams(8).map((t) => t.teamId), [8]);
    expect(catalog.currentCompetitions(8).map((c) => c.competitionId), [8]);
    expect(catalog.currentCompetitions(19), isEmpty);
    expect(catalog.resolve(19), isNull);
    expect(catalog.resolve(8)?.seasonId, 28083);
    expect(catalog.resolve(8)?.competitionName, 'Premier League');
    expect(notifiedSeasonIds, [28083]);
    await teams.initialize();
    expect(requests, 1);
  });

  test('failed catalog retries without publishing partially parsed data',
      () async {
    var requests = 0;
    final invalid = jsonDecode(fixture('api_catalog')) as Map<String, dynamic>;
    invalid['memberships'] = [
      ...(invalid['memberships'] as List),
      {'team_id': 8},
    ];
    final catalog = FootballCatalog(api: api((_) async {
      requests++;
      return http.Response(
          requests == 1 ? jsonEncode(invalid) : fixture('api_catalog'), 200);
    }));
    await expectLater(catalog.initialize(), throwsA(anything));
    expect(catalog.teams.value, isEmpty);
    expect(catalog.seasons.value, isEmpty);
    expect(catalog.competitions.value, isEmpty);
    expect(catalog.memberships, isEmpty);
    expect(catalog.resolve(8), isNull);
    await catalog.initialize();
    expect(catalog.teams.value, hasLength(2));
    expect(catalog.resolve(8)?.seasonId, 28083);
  });

  test('current selectors preserve cup membership and domestic league choice',
      () async {
    final data = jsonDecode(fixture('api_catalog')) as Map<String, dynamic>;
    (data['seasons'] as List).add({
      'season_id': 30000,
      'competition_id': 2,
      'name': '2026/2027',
      'is_current': true,
    });
    (data['memberships'] as List).insertAll(0, [
      {'team_id': 8, 'season_id': 23614, 'competition_id': 8},
      {'team_id': 19, 'season_id': 30000, 'competition_id': 2},
      {'team_id': 8, 'season_id': 30000, 'competition_id': 2},
    ]);
    final catalog = FootballCatalog(
        api: api((_) async => http.Response(jsonEncode(data), 200)));
    await catalog.initialize();

    expect(catalog.currentTeams(8).map((t) => t.teamId), [8]);
    expect(catalog.currentTeams(2).map((t) => t.teamId), [8, 19]);
    expect(catalog.currentCompetitions(8).map((c) => c.competitionId), [8, 2]);
    expect(catalog.currentCompetitions(19).map((c) => c.competitionId), [2]);
    expect(catalog.resolve(8)?.seasonId, 28083);
    expect(catalog.resolve(8)?.competitionId, 8);
    expect(catalog.resolve(19), isNull);
    expect(catalog.resolve(-1), isNull);
  });

  test('team edit filtering stays responsive with production-sized catalog',
      () async {
    // 운영 기록과 행 수만 같은 합성 데이터로 수 초간 멈추던 연산을 확인해요.
    final data = {
      'teams':
          List.generate(2116, (i) => {'team_id': i + 1, 'name': 'Team $i'}),
      'competitions': [
        {'competition_id': 8, 'name': 'Premier League'},
      ],
      'seasons': List.generate(
          116,
          (i) => {
                'season_id': i + 1,
                'competition_id': 8,
                'name': '$i',
                'is_current': i == 0,
              }),
      'memberships': List.generate(
          7221,
          (i) => {
                'team_id': i % 2116 + 1,
                'season_id': i % 116 + 1,
                'competition_id': 8,
              }),
    };
    final catalog = FootballCatalog(
        api: api((_) async => http.Response(jsonEncode(data), 200)));
    await catalog.initialize();
    final eligibility = TeamPageEligibility(catalog);
    final watch = Stopwatch()..start();
    final contexts = CatalogTeamRepository(catalog)
        .allTeams
        .where((team) => eligibility.supports(team.teamId))
        .map((team) => catalog.resolve(team.teamId))
        .toList();
    watch.stop();

    expect(contexts, hasLength(63));
    expect(contexts.every((context) => context?.seasonId == 1), isTrue);
    expect(watch.elapsed, lessThan(const Duration(seconds: 1)),
        reason: 'Opening the team editor must not block the UI for seconds.');
  });

  test('shared search response preserves Korean, nulls, zero scores and UTC',
      () async {
    final repo = ApiSearchRepository(api: api((request) async {
      expect(request.url.path, '/v1/search');
      expect(request.url.queryParameters, {'q': '선수', 'limit': '12'});
      return http.Response.bytes(utf8.encode(fixture('api_search')), 200);
    }));
    final result = await repo.search(' 선수 ');
    expect(result.players.single.name, '선수 Example');
    expect(result.players.single.image, isNull);
    expect(result.fixtures.single.homeScore, 0);
    expect(result.fixtures.single.homePenaltyScore, isNull);
    expect(result.fixtures.single.kickoff, DateTime.utc(2026, 9, 1, 18));
  });

  test('shared player schemas supply detail and ranking to existing parsers',
      () async {
    final client = api((request) async => http.Response.bytes(
        utf8.encode(fixture(request.url.path.endsWith('/detail')
            ? 'player_detail'
            : 'api_player_directory')),
        200));
    final detail = await ApiPlayerDetailRepository(api: client).load(9967153);
    expect(detail.matches.first.metrics, isNotEmpty);
    expect(detail.profile.image, isNull);
    final ranking = await ApiPlayerDirectoryRepository(api: client).ranking();
    expect(ranking.items.single.id, 123);
    expect(ranking.items.single.score, 8.2);
  });
}
