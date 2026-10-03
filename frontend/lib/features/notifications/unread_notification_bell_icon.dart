import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_none_rounded, size: 32, color: color),
          if (hasUnread)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                key: badgeKey,
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFD82457),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      );
}
