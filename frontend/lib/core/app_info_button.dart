import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class AppInfoButton extends StatelessWidget {
  const AppInfoButton({
    super.key,
    required this.message,
    this.layoutSize = 20,
  });

  final String message;
  final double layoutSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tr(context, 'Explanation'),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDialog<void>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black26,
          builder: (dialogContext) => Dialog(
            key: const ValueKey('app-info-popup'),
            backgroundColor: AppColors.of(dialogContext).cardBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  tr(dialogContext, message),
                  style: Body2.style.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        child: SizedBox.square(
          dimension: layoutSize,
          child: const OverflowBox(
            minWidth: 20,
            maxWidth: 20,
            minHeight: 20,
            maxHeight: 20,
            alignment: Alignment.center,
            child: Icon(Icons.help_outline, size: 20),
          ),
        ),
      ),
    );
  }
}
