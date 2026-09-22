import 'package:flutter/material.dart';

/// Shared measurements exported from the app dropdown component in Figma.
abstract final class AppDropdownTokens {
  static const double height = 40;
  static const double radius = 16;
  static const double iconSize = 24;
  static const double gap = 8;

  static const EdgeInsets triggerPadding = EdgeInsets.fromLTRB(16, 8, 8, 8);
  static const EdgeInsets compactPadding = EdgeInsets.all(8);
  static const EdgeInsets menuPadding = EdgeInsets.all(12);
  static const EdgeInsets selectedOptionPadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 4);

  static const double selectedOptionRadius = 8;
}

class AppDropdownChevron extends StatelessWidget {
  const AppDropdownChevron({
    super.key,
    this.expanded = false,
    this.color,
  });

  final bool expanded;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
      size: AppDropdownTokens.iconSize,
      color: color ?? Theme.of(context).colorScheme.onSurface,
    );
  }
}
