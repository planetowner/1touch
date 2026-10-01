import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/injuries/api/api_team_injury_repository.dart';
import 'package:onetouch/data/injuries/team_injury_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final TeamInjuryRepository teamInjuryRepository = ApiTeamInjuryRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);
