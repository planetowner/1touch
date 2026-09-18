import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/transfers/api/api_transfer_mapper.dart';
import 'package:onetouch/data/transfers/api/api_transfer_response.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/data/teams/team_feature_unavailable_exception.dart';
import 'package:onetouch/models/team_transfer_window.dart';

/// HTTP implementation of `GET /v1/teams/{team_id}/transfers`.
class ApiTransferRepository implements TransferRepository {
  ApiTransferRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<int, TeamTransferWindow>> _cachedWindows =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, TeamTransferWindow>> get cachedWindows =>
      _cachedWindows;

  @override
  TeamTransferWindow? cachedForTeam(int teamId) => _cachedWindows.value[teamId];

  @override
  Future<TeamTransferWindow> loadForTeam(int teamId) async {
    final cached = cachedForTeam(teamId);
    if (cached != null) return cached;

    final uri = _apiBaseUri.resolve('teams/$teamId/transfers');
    final response = await _client.get(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode == 404) {
      throw TeamFeatureUnavailableException(
        teamId: teamId,
        feature: 'Transfers',
      );
    }
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Transfers request failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the transfers response to be a JSON object.',
      );
    }

    final window = teamTransferWindowFromApiResponse(
      ApiTeamTransfersResponse.fromJson(decoded),
      teamId: teamId,
    );
    _cachedWindows.value = Map.unmodifiable({
      ..._cachedWindows.value,
      teamId: window,
    });
    return window;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
