import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/chat/api/api_chat_mapper.dart';
import 'package:onetouch/data/chat/api/api_chat_response.dart';
import 'package:onetouch/data/chat/chat_repository.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

class ApiChatRepository implements ChatRepository {
  ApiChatRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;
  final ValueNotifier<Map<int, List<FixtureChatMessage>>> _cachedHistories =
      ValueNotifier(const {});

  @override
  ValueListenable<Map<int, List<FixtureChatMessage>>> get cachedHistories =>
      _cachedHistories;

  @override
  List<FixtureChatMessage> cachedHistoryForFixture(int fixtureId) =>
      _cachedHistories.value[fixtureId] ?? const [];

  @override
  Future<List<FixtureChatMessage>> loadHistory({
    required int fixtureId,
    int? beforeId,
    int? afterId,
    int limit = 50,
  }) async {
    if (fixtureId < 1) {
      throw RangeError.value(fixtureId, 'fixtureId', 'Must be positive');
    }
    if (beforeId != null && beforeId < 1) {
      throw RangeError.value(beforeId, 'beforeId', 'Must be positive');
    }
    if (afterId != null && afterId < 0) {
      throw RangeError.value(afterId, 'afterId', 'Must not be negative');
    }
    if (beforeId != null && afterId != null) {
      throw ArgumentError('Use either beforeId or afterId, not both.');
    }
    if (limit < 1 || limit > 100) {
      throw RangeError.range(limit, 1, 100, 'limit');
    }

    final query = <String, String>{'limit': '$limit'};
    if (beforeId != null) query['before_id'] = '$beforeId';
    if (afterId != null) query['after_id'] = '$afterId';
    final uri = _api.baseUri
        .resolve('fixtures/$fixtureId/chat/messages')
        .replace(queryParameters: query);
    final response = await _api.get(
      uri,
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final page = ApiChatHistoryResponse.fromJson(decoded).items.map((item) {
      final message = chatMessageFromApiResponse(
        item,
        apiBaseUri: _api.baseUri,
      );
      if (message.fixtureId != fixtureId) {
        throw FormatException(
          'Expected fixture_id $fixtureId but received ${message.fixtureId}.',
        );
      }
      return message;
    }).toList(growable: false);
    _verifyIncreasingIds(page);
    _mergeIntoCache(fixtureId, page);
    return List.unmodifiable(page);
  }

  @override
  Future<void> reportMessage({
    required int messageId,
    required String reason,
  }) async {
    if (messageId < 1) {
      throw RangeError.value(messageId, 'messageId', 'Must be positive');
    }
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty ||
        normalizedReason.length > maxChatReportReasonLength) {
      throw ArgumentError.value(
        reason,
        'reason',
        'Must contain between 1 and $maxChatReportReasonLength characters',
      );
    }
    final uri = _api.baseUri.resolve('chat/messages/$messageId/report');
    final response = await _api.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'reason': normalizedReason}),
    );
    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException(
        'Expected the chat-message report response to return ok=true.',
      );
    }
  }

  void _verifyIncreasingIds(List<FixtureChatMessage> messages) {
    for (var index = 1; index < messages.length; index++) {
      if (messages[index - 1].messageId >= messages[index].messageId) {
        throw const FormatException(
          'Expected chat messages in strictly increasing cursor order.',
        );
      }
    }
  }

  void _mergeIntoCache(int fixtureId, List<FixtureChatMessage> page) {
    final byId = {
      for (final message in cachedHistoryForFixture(fixtureId))
        message.messageId: message,
      for (final message in page) message.messageId: message,
    };
    final merged = byId.values.toList()
      ..sort((left, right) => left.messageId.compareTo(right.messageId));
    _cachedHistories.value = Map.unmodifiable(
      <int, List<FixtureChatMessage>>{
        ..._cachedHistories.value,
        fixtureId: List.unmodifiable(merged),
      },
    );
  }
}
