import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/viewer_country_config.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/local/local_cache_store_provider.dart';

final HomeRepository homeRepository = _createHomeRepository();

HomeRepository _createHomeRepository() {
  final repository = ApiHomeRepository(
    api: apiClient,
    viewerCountry: ViewerCountryConfig.fromEnvironment(),
    cacheStore: localCacheStore,
  );
  authSession.addListener(repository.clearSnapshots);
  return repository;
}
