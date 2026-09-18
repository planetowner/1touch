import 'package:onetouch/data/chat/api/api_chat_response.dart';
import 'package:onetouch/models/fixture_chat_message.dart';

FixtureChatMessage chatMessageFromApiResponse(
  ApiChatMessageResponse response, {
  required Uri apiBaseUri,
}) {
  if (response.messageId < 1 || response.fixtureId < 1) {
    throw const FormatException(
      'Expected positive chat message and fixture IDs.',
    );
  }
  if (response.text.trim().isEmpty) {
    throw const FormatException('Expected non-empty chat message text.');
  }
  if (response.authorDeleted != (response.userId == null)) {
    throw const FormatException(
      'Expected author_deleted to match nullable user_id.',
    );
  }
  if (!response.authorDeleted &&
      (response.username == null || response.username!.trim().isEmpty)) {
    throw const FormatException(
      'Expected an active chat author to have a username.',
    );
  }
  final createdAt = DateTime.tryParse(response.createdAt);
  if (createdAt == null || !createdAt.isUtc) {
    throw const FormatException('Expected created_at to be ISO 8601 UTC.');
  }
  return FixtureChatMessage(
    messageId: response.messageId,
    fixtureId: response.fixtureId,
    userId: response.userId,
    username: response.username,
    text: response.text,
    createdAt: createdAt,
    avatarUrl: _resolveOptionalUri(apiBaseUri, response.avatarUrl),
    authorDeleted: response.authorDeleted,
  );
}

String? _resolveOptionalUri(Uri baseUri, String? value) {
  if (value == null) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    throw FormatException('Invalid chat avatar URI: $value');
  }
  final resolved = parsed.hasScheme ? parsed : baseUri.resolveUri(parsed);
  if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
      resolved.host.isEmpty) {
    throw FormatException('Expected an HTTP(S) chat avatar URI: $value');
  }
  return resolved.toString();
}
