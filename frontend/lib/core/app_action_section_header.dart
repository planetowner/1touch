import 'package:flutter/material.dart';

class AppActionSectionHeader extends StatelessWidget {
  const AppActionSectionHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final Widget title;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Padding(
        // 48px 터치 영역의 아래 여백 12px과 합쳐, 24px 아이콘 아래를 16px 띄워요.
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          children: [
            Expanded(child: title),
            IconButton(
              tooltip: tooltip,
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              alignment: Alignment.centerRight,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: Icon(icon,
                  size: 24, color: Theme.of(context).colorScheme.onSurface),
            ),
          ],
        ),
      );
}
