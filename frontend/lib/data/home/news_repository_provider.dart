import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/home/api/api_news_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';

final NewsRepository newsRepository = ApiNewsRepository(
  api: apiClient,
);
