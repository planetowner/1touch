import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/best_eleven/api/api_best_eleven_mapper.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_response.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/models/team_best_eleven.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/best-eleven`.
class ApiBestElevenRepository implements BestElevenRepository {
  ApiBestElevenRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<BestElevenQuery, TeamBestEleven>> _cachedLineups =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<BestElevenQuery, TeamBestEleven>> get cachedLineups =>
      _cachedLineups;

  @override
  TeamBestEleven? cachedForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) {
    return _cachedLineups.value[BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    )];
  }

  @override
  Future<TeamBestEleven?> loadForTeam(
    int teamId, {
    int? seasonId,
    String? formation,
  }) async {
    final query = BestElevenQuery(
      teamId: teamId,
      seasonId: seasonId,
      formation: formation,
    );
    final cached = _cachedLineups.value[query];
    if (cached != null) return cached;

    final uri = _apiBaseUri.resolve('teams/$teamId/best-eleven').replace(
      queryParameters: {
        if (seasonId != null) 'season_id': '$seasonId',
        if (query.formation != null) 'formation': query.formation!,
      },
    );
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Best eleven request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the Best Eleven response to be a JSON object.',
      );
    }

    final apiResponse = ApiBestElevenResponse.fromJson(decoded);
    if (apiResponse.teamId != teamId) {
      throw FormatException(
        'Expected team_id $teamId but received ${apiResponse.teamId}.',
      );
    }
    if (seasonId != null && apiResponse.seasonId != seasonId) {
      throw FormatException(
        'Expected season_id $seasonId but received ${apiResponse.seasonId}.',
      );
    }
    if (query.formation != null && apiResponse.formation != query.formation) {
      throw FormatException(
        'Expected formation ${query.formation} but received '
        '${apiResponse.formation}.',
      );
    }

    final lineup = teamBestElevenFromApiResponse(apiResponse);
    _cachedLineups.value = Map.unmodifiable({
      ..._cachedLineups.value,
      query: lineup,
    });
    return lineup;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
