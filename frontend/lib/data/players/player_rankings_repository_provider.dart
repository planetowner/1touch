import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/players/api/api_player_rankings_repository.dart';
import 'package:onetouch/data/players/player_ranking_season_resolver.dart';
import 'package:onetouch/data/players/player_rankings_repository.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The session-aware client injects the latest login token for every request.
final PlayerRankingsRepository playerRankingsRepository =
    ApiPlayerRankingsRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);

/// Temporary local label-to-season resolver. Replace its season source when a
/// shared backend season-options endpoint becomes available.
final PlayerRankingSeasonResolver playerRankingSeasonResolver =
    PlayerRankingSeasonResolver(
  competitionRepository: competitionRepository,
  seasonRepository: seasonRepository,
);
