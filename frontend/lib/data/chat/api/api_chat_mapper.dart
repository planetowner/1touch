import 'package:onetouch/data/chat/api/api_chat_response.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

FixtureChatMessage chatMessageFromApiResponse(
  ApiChatMessageResponse response,
) {
  if (response.messageId < 1 || response.fixtureId < 1) {
    throw const FormatException(
      'Expected positive chat message and fixture IDs.',
    );
  }
  if (response.text.trim().isEmpty) {
    throw const FormatException('Expected non-empty chat message text.');
  }
  if (response.authorDeleted
      ? response.nicknameEn != null ||
          response.nicknameKo != null ||
          response.isMine
      : response.nicknameEn?.trim().isNotEmpty != true ||
          response.nicknameKo?.trim().isNotEmpty != true) {
    throw const FormatException(
      'Expected anonymous nicknames for active chat authors only.',
    );
  }
  final createdAt = DateTime.tryParse(response.createdAt);
  if (createdAt == null || !createdAt.isUtc) {
    throw const FormatException('Expected created_at to be ISO 8601 UTC.');
  }
  return FixtureChatMessage(
    messageId: response.messageId,
    fixtureId: response.fixtureId,
    nicknameEn: response.nicknameEn,
    nicknameKo: response.nicknameKo,
    isMine: response.isMine,
    text: response.text,
    createdAt: createdAt,
    authorDeleted: response.authorDeleted,
  );
}
