import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/home/api/api_news_repository.dart';
import 'package:onetouch/data/home/home_content_repository.dart';
import 'package:onetouch/data/home/home_content_service.dart';

final ApiConfig _apiConfig = ApiConfig.fromEnvironment();

final HomeContentRepository homeContentRepository = HomeContentService(
  newsRepository: ApiNewsRepository(
    client: http.Client(),
    apiBaseUri: _apiConfig.baseUri,
    requestHeaders: _apiConfig.requestHeaders,
  ),
  languageCode: () => PlatformDispatcher.instance.locale.languageCode,
);
