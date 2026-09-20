import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/home/api/api_news_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final NewsRepository newsRepository = ApiNewsRepository(
  client: http.Client(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
