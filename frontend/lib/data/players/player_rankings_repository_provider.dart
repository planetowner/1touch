import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/players/api/api_player_rankings_repository.dart';
import 'package:onetouch/data/players/player_ranking_season_resolver.dart';
import 'package:onetouch/data/players/player_rankings_repository.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

/// Staged real provider kept separate from the mock-backed `playerRepository`.
///
/// The current API configuration captures the environment session token when
/// this library is initialized. Replace that static header source with the
/// authenticated session when saved-login restoration is implemented.
final PlayerRankingsRepository playerRankingsRepository =
    ApiPlayerRankingsRepository(
  client: http.Client(),
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
