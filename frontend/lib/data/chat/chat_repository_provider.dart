import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/chat/api/api_chat_repository.dart';
import 'package:onetouch/data/chat/chat_repository.dart';

final ChatRepository chatRepository = ApiChatRepository(
  api: apiClient,
);
