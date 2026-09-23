import 'package:flutter/foundation.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

class TestMatchAnalysisRepository implements MatchAnalysisRepository {
  TestMatchAnalysisRepository(this.analysis, this.shotMap)
      : cachedAnalyses = ValueNotifier({analysis.fixtureId: analysis}),
        cachedShotMaps = ValueNotifier({shotMap.fixtureId: shotMap});

  final MatchTacticalAnalysis analysis;
  final MatchShotMap shotMap;

  @override
  final ValueNotifier<Map<int, MatchTacticalAnalysis>> cachedAnalyses;

  @override
  final ValueNotifier<Map<int, MatchShotMap>> cachedShotMaps;

  @override
  MatchTacticalAnalysis? cachedAnalysisForFixture(int fixtureId) =>
      cachedAnalyses.value[fixtureId];

  @override
  MatchShotMap? cachedShotMapForFixture(int fixtureId) =>
      cachedShotMaps.value[fixtureId];

  @override
  Future<MatchTacticalAnalysis> loadAnalysis(int fixtureId) async => analysis;

  @override
  Future<MatchShotMap> loadShotMap(int fixtureId) async => shotMap;
}
