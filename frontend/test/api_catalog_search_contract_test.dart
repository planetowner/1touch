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
    final pending = Future.wait(
        [teams.initialize(), competitions.initialize(), seasons.initialize()]);
    gate.complete(http.Response(fixture('api_catalog'), 200));
    await pending;
    expect(requests, 1);
    expect(teams.findById(8)?.name, 'Example United');
    expect(competitions.domesticCompetitions.single.competitionId, 8);
    expect(seasons.currentForCompetition(8)?.seasonId, 28083);
    expect(seasons.currentForCompetition(8)?.startingAt, isNull);
    expect(catalog.currentTeams(8).map((t) => t.teamId), [8]);
    expect(catalog.resolve(19), isNull);
    expect(catalog.resolve(8)?.seasonId, 28083);
    await teams.initialize();
    expect(requests, 1);
  });

  test('failed catalog retries without publishing partially parsed data',
      () async {
    var requests = 0;
    final catalog = FootballCatalog(api: api((_) async {
      requests++;
      return http.Response(requests == 1 ? '{}' : fixture('api_catalog'), 200);
    }));
    await expectLater(catalog.initialize(), throwsA(anything));
    expect(catalog.teams.value, isEmpty);
    await catalog.initialize();
    expect(catalog.teams.value, hasLength(2));
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
