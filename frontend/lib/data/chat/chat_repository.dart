import 'package:flutter/foundation.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

abstract interface class ChatRepository {
  ValueListenable<Map<int, List<FixtureChatMessage>>> get cachedHistories;

  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId);

  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    int? beforeId,
    int? afterId,
    int limit = 50,
  });
}
