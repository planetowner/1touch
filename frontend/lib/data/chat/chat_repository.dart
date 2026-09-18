import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

const int maxChatReportReasonLength = 500;

abstract interface class ChatRepository {
  ValueListenable<Map<int, List<FixtureChatMessage>>> get cachedHistories;

  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId);

  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    int? beforeId,
    int? afterId,
    int limit = 50,
  });

  Future<void> reportMessage({
    required int messageId,
    required String reason,
  });
}
