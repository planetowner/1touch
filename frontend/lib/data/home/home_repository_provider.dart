import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/core/viewer_country_config.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';

final HomeRepository homeRepository = ApiHomeRepository(
  api: apiClient,
  viewerCountry: ViewerCountryConfig.fromEnvironment(),
);
