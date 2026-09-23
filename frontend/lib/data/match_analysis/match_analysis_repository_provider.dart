import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/match_analysis/api/api_match_analysis_repository.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';

final MatchAnalysisRepository matchAnalysisRepository =
    ApiMatchAnalysisRepository(
  api: apiClient,
);
