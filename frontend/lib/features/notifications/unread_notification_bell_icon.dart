import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class UnreadNotificationBellIcon extends StatelessWidget {
  const UnreadNotificationBellIcon({
    super.key,
    required this.color,
    required this.hasUnread,
    this.badgeKey,
  });

  final Color color;
  final bool hasUnread;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 32,
        child: FittedBox(
          child: SvgPicture.asset(
            hasUnread
                ? 'assets/community/bell_unread.svg'
                : 'assets/community/bell_default.svg',
            key: hasUnread ? badgeKey : null,
            // 읽지 않은 알림이 있을 때만 끊어진 종과 빨간 점을 함께 보여줘요.
            colorMapper: _BellColorMapper(color),
          ),
        ),
      );
}

class _BellColorMapper extends ColorMapper {
  const _BellColorMapper(this.foreground);
  final Color foreground;

  @override
  Color substitute(
          String? id, String elementName, String attributeName, Color color) =>
      // 밝은 테마에서는 흰 종만 바꾸고, 원본의 빨간 알림 표시는 유지해요.
      color == Colors.white ? foreground : color;

  @override
  bool operator ==(Object other) =>
      other is _BellColorMapper && other.foreground == foreground;

  @override
  int get hashCode => foreground.hashCode;
}
