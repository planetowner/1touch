import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

const int maxChatReportReasonLength = 500;
typedef ChatRoom = ({int fixtureId, String language});

abstract interface class ChatRepository {
  ValueListenable<Map<ChatRoom, List<FixtureChatMessage>>> get cachedHistories;

  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId,
      {required String language});

  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    required String language,
    int? beforeId,
    int? afterId,
    int limit = 50,
  });

  Future<void> reportMessage({
    required int messageId,
    required String reason,
  });
}
