import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/app_close_header.dart';
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
            backgroundColor:
                Theme.of(dialogContext).brightness == Brightness.dark
                    ? AppPalette.lightGrey
                    : AppPalette.lightModeDarkGrey,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 345),
              child: Padding(
                key: const ValueKey('app-info-content'),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppCloseHeader(
                      closeKey: const ValueKey('app-info-close'),
                      onClose: () => Navigator.of(dialogContext).pop(),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        tr(dialogContext, message),
                        style: Body1.style.copyWith(
                          color: Theme.of(dialogContext).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
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
