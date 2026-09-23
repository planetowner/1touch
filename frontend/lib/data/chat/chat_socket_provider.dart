import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/chat/api/api_chat_socket.dart';
import 'package:onetouch/data/chat/chat_socket.dart';

final ChatSocket chatSocket = ApiChatSocket(
  apiBaseUri: apiClient.baseUri,
  sessionToken: () => authSession.accessToken,
);
