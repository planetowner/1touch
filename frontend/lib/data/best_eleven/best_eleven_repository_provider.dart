import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/best_eleven/api/api_best_eleven_repository.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final BestElevenRepository bestElevenRepository = ApiBestElevenRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
