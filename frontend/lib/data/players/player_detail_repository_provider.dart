import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/players/api/api_player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final PlayerDetailRepository playerDetailRepository =
    ApiPlayerDetailRepository(api: apiClient, cacheStore: localCacheStore);
