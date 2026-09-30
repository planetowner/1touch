import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/contracts/api/api_team_contract_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final TeamContractRepository teamContractRepository = ApiTeamContractRepository(
  api: apiClient,
  cacheStore: localCacheStore,
);
