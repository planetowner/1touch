import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_mapper.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_response.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

class ApiMatchAnalysisRepository implements MatchAnalysisRepository {
  ApiMatchAnalysisRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
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
    final uri = _api.baseUri.resolve(path);
    final response = await _api.get(
      uri,
    );
    return _api.decodeJson<Map<String, dynamic>>(response);
  }

  void _verifyFixture(int expected, int actual) {
    if (expected != actual) {
      throw FormatException(
        'Expected fixture_id $expected but received $actual.',
      );
    }
  }
}
