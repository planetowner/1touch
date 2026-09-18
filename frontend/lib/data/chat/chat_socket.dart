import 'package:onetouch/models/fixture_chat_message.dart';

const int maxChatMessageLength = 2000;

abstract interface class ChatSocket {
  Future<ChatSocketSession> connect(int fixtureId);
}

abstract interface class ChatSocketSession {
  Stream<FixtureChatMessage> get messages;

  Future<void> send(String text);

  Future<void> close();
}

class ChatSocketException implements Exception {
  const ChatSocketException({
    required this.message,
    this.closeCode,
    this.closeReason,
  });

  final String message;
  final int? closeCode;
  final String? closeReason;

  bool get isUnauthorized => closeCode == 4401;
  bool get isForbidden => closeCode == 4403;

  @override
  String toString() => message;
}
