import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/community/api/api_community_followers_response.dart';
import 'package:onetouch/data/community/api/api_community_rules_mapper.dart';
import 'package:onetouch/data/community/api/api_community_rules_response.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/models/community_rules.dart';

class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<int> loadFollowerCount({required int teamId}) async {
    _validateTeamId(teamId);

    final uri = _api.baseUri.resolve('community/followers').replace(
      queryParameters: {'team_id': '$teamId'},
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final result = ApiCommunityFollowersResponse.fromJson(decoded);
    if (result.teamId != teamId) {
      throw FormatException(
        'Expected follower count for team $teamId, received team '
        '${result.teamId}.',
      );
    }
    return result.followerCount;
  }

  @override
  Future<CommunityRules> loadRules({
    required int teamId,
    required CommunityLanguage language,
  }) async {
    _validateTeamId(teamId);

    final uri = _api.baseUri.resolve('community/rules').replace(
      queryParameters: {
        'team_id': '$teamId',
        'language': language.apiValue,
      },
    );
    final response = await _api.get(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final rules = communityRulesFromApiResponse(
      ApiCommunityRulesResponse.fromJson(decoded),
    );
    if (rules.language != language) {
      throw FormatException(
        'Expected community rules in ${language.apiValue}, received '
        '${rules.language.apiValue}.',
      );
    }
    return rules;
  }

  static void _validateTeamId(int teamId) {
    if (teamId < 1) {
      throw RangeError.value(teamId, 'teamId', 'must be positive');
    }
  }
}
