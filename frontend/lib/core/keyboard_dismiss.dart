import 'package:flutter/material.dart';

/// Keeps the keyboard active while interacting with the focused input, and
/// dismisses it as soon as an interaction starts outside that input.
class AppKeyboardDismissBoundary extends StatelessWidget {
  const AppKeyboardDismissBoundary({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) {
            intent.focusNode.unfocus();
            return null;
          },
        ),
      },
      child: child,
    );
  }
}
