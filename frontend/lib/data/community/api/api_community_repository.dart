import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/community/api/api_community_followers_response.dart';
import 'package:onetouch/data/community/api/api_community_rules_mapper.dart';
import 'package:onetouch/data/community/api/api_community_rules_response.dart';
import 'package:onetouch/data/community/community_repository.dart';
import 'package:onetouch/models/community_rules.dart';

class ApiCommunityRepository implements CommunityRepository {
  ApiCommunityRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<int> loadFollowerCount({required int teamId}) async {
    _validateTeamId(teamId);

    final uri = _apiBaseUri.resolve('community/followers').replace(
      queryParameters: {'team_id': '$teamId'},
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Community follower-count request failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the community follower-count response to be an object.',
      );
    }
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

    final uri = _apiBaseUri.resolve('community/rules').replace(
      queryParameters: {
        'team_id': '$teamId',
        'language': language.apiValue,
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Community-rules request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the community-rules response to be an object.',
      );
    }
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

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
