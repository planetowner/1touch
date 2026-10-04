import 'package:flutter/foundation.dart';

@immutable
class FixtureChatMessage {
  const FixtureChatMessage({
    required this.messageId,
    required this.fixtureId,
    required this.nicknameEn,
    required this.nicknameKo,
    required this.isMine,
    required this.text,
    required this.createdAt,
    required this.authorDeleted,
  });

  final int messageId;
  final int fixtureId;
  final String? nicknameEn;
  final String? nicknameKo;
  final bool isMine;
  final String text;
  final DateTime createdAt;
  final bool authorDeleted;

  // 선수명만 언어에 맞추고, 같은 참여자를 가리키는 4자리 코드는 유지해요.
  String displayAuthor(String languageCode) {
    if (authorDeleted) return 'Deleted user';

    // 저장된 닉네임을 바꾸지 않고 과거·실시간 메시지의 표시 형식을 맞춰요.
    final [name, suffix] =
        (languageCode == 'ko' ? nicknameKo! : nicknameEn!).split('_');
    return '${name[0].toLowerCase()}${name.substring(1)}_${suffix.toLowerCase()}';
  }
}
