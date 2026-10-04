import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/catalog/football_catalog.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';

void main() {
  test('test season supplies the existing league selector and team context',
      () async {
    final config = ApiConfig.fromValues(
      baseUri: 'https://api.1touch.football/live-test/v1/',
    );
    final catalog = FootballCatalog(
      api: ApiClient(
        baseUri: config.baseUri,
        requestHeaders: () => {},
        client: MockClient((request) async {
          expect(request.url.path, '/live-test/v1/catalog');
          return http.Response(
              jsonEncode({
                'teams': [
                  {'team_id': 2921, 'name': 'Las Palmas'},
                  {'team_id': 361, 'name': 'Real Valladolid'},
                ],
                'competitions': [
                  {'competition_id': 567, 'name': 'La Liga 2'},
                ],
                'seasons': [
                  {
                    'season_id': 28479,
                    'competition_id': 567,
                    'name': '2026/2027',
                    'is_current': true,
                  },
                ],
                'memberships': [
                  for (final teamId in [2921, 361])
                    {
                      'team_id': teamId,
                      'season_id': 28479,
                      'competition_id': 567,
                    },
                ],
              }),
              200);
        }),
      ),
    );
    await catalog.initialize();
    expect(
        CatalogCompetitionRepository(catalog).domesticCompetitions.single.name,
        'La Liga 2');
    expect(catalog.currentTeams(567).map((team) => team.teamId), [2921, 361]);
    expect(catalog.resolve(2921)?.seasonId, 28479);
    expect(TeamPageEligibility(catalog).supports(2921), isTrue);
  });
}
