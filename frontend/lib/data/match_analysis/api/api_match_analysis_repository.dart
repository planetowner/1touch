import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:onetouch/data/match_analysis/api/api_match_analysis_mapper.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_response.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

class ApiMatchAnalysisRepository implements MatchAnalysisRepository {
  ApiMatchAnalysisRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;
  final ValueNotifier<Map<int, MatchTacticalAnalysis>> _cachedAnalyses =
      ValueNotifier(const {});
  final ValueNotifier<Map<int, MatchShotMap>> _cachedShotMaps =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, MatchTacticalAnalysis>> get cachedAnalyses =>
      _cachedAnalyses;

  @override
  ValueListenable<Map<int, MatchShotMap>> get cachedShotMaps => _cachedShotMaps;

  @override
  MatchTacticalAnalysis? cachedAnalysisForFixture(int fixtureId) =>
      _cachedAnalyses.value[fixtureId];

  @override
  MatchShotMap? cachedShotMapForFixture(int fixtureId) =>
      _cachedShotMaps.value[fixtureId];

  @override
  Future<MatchTacticalAnalysis> loadAnalysis(int fixtureId) async {
    final cached = cachedAnalysisForFixture(fixtureId);
    if (cached != null) return cached;
    final decoded = await _getObject('fixtures/$fixtureId/analysis');
    final result = matchAnalysisFromApiResponse(
      ApiMatchAnalysisResponse.fromJson(decoded),
    );
    _verifyFixture(fixtureId, result.fixtureId);
    _cachedAnalyses.value = Map.unmodifiable({
      ..._cachedAnalyses.value,
      fixtureId: result,
    });
    return result;
  }

  @override
  Future<MatchShotMap> loadShotMap(int fixtureId) async {
    final cached = cachedShotMapForFixture(fixtureId);
    if (cached != null) return cached;
    final decoded = await _getObject('fixtures/$fixtureId/shotmap');
    final result = matchShotMapFromApiResponse(
      ApiMatchShotMapResponse.fromJson(decoded),
    );
    _verifyFixture(fixtureId, result.fixtureId);
    _cachedShotMaps.value = Map.unmodifiable({
      ..._cachedShotMaps.value,
      fixtureId: result,
    });
    return result;
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final uri = _apiBaseUri.resolve(path);
    final response = await _client.get(
      uri,
      headers: {'Accept': 'application/json', ..._requestHeaders},
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Match analysis request failed with status ${response.statusCode}.',
        uri,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const FormatException(
      'Expected the match analysis response to be a JSON object.',
    );
  }

  void _verifyFixture(int expected, int actual) {
    if (expected != actual) {
      throw FormatException(
        'Expected fixture_id $expected but received $actual.',
      );
    }
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
