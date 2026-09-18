import 'package:flutter/foundation.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';

abstract interface class MatchAnalysisRepository {
  ValueListenable<Map<int, MatchTacticalAnalysis>> get cachedAnalyses;
  ValueListenable<Map<int, MatchShotMap>> get cachedShotMaps;

  MatchTacticalAnalysis? cachedAnalysisForFixture(int fixtureId);
  MatchShotMap? cachedShotMapForFixture(int fixtureId);

  Future<MatchTacticalAnalysis> loadAnalysis(int fixtureId);
  Future<MatchShotMap> loadShotMap(int fixtureId);
}
