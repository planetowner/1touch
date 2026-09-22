import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/chat/api/api_chat_socket.dart';
import 'package:onetouch/data/chat/chat_socket.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final ChatSocket chatSocket = ApiChatSocket(
  apiBaseUri: _apiConfig.baseUri,
  sessionTokenProvider: () => ApiConfig.currentAccessToken ?? '',
);
