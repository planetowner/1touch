import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_mapper.dart';
import 'package:onetouch/data/fixtures/api/api_fixture_response.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/data/teams/api/api_team_mapper.dart';

class SearchResults {
  const SearchResults(
      {this.players = const [],
      this.teams = const [],
      this.fixtures = const []});
  final List<PlayerCandidate> players;
  final List<Team> teams;
  final List<Fixture> fixtures;
}

abstract interface class SearchRepository {
  Future<SearchResults> search(String query);
}

final SearchRepository searchRepository = ApiSearchRepository(api: apiClient);

class ApiSearchRepository implements SearchRepository {
  ApiSearchRepository({required ApiClient api}) : _api = api;
  final ApiClient _api;

  @override
  Future<SearchResults> search(String query) async {
    final response = await _api.get(_api.baseUri
        .resolve('search')
        .replace(queryParameters: {'q': query.trim(), 'limit': '12'}));
    final json = _api.decodeJson<Map<String, dynamic>>(response);
    return SearchResults(
      players: (json['players'] as List)
          .cast<Map<String, dynamic>>()
          .map(playerCandidateFromJson)
          .toList(),
      teams: (json['teams'] as List)
          .cast<Map<String, dynamic>>()
          .map(teamFromApiJson)
          .toList(),
      fixtures: (json['fixtures'] as List)
          .cast<Map<String, dynamic>>()
          .map((r) => fixtureFromApiResponse(ApiFixtureResponse.fromJson(r)))
          .toList(),
    );
  }
}
