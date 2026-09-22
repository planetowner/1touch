import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/chat/api/api_chat_repository.dart';
import 'package:onetouch/data/chat/chat_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final ChatRepository chatRepository = ApiChatRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
