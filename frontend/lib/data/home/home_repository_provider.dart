import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/home/api/api_home_repository.dart';
import 'package:onetouch/data/home/home_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final HomeRepository homeRepository = ApiHomeRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
