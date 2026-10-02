import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// A sheet or dialog header with an optional centered title and trailing X.
/// The parent owns its outer padding and the spacing below the header.
class AppCloseHeader extends StatelessWidget {
  const AppCloseHeader({
    super.key,
    required this.onClose,
    this.title,
    this.titleStyle,
    this.closeKey,
    this.buttonSize = 48,
    this.iconSize = 24,
  });

  final VoidCallback onClose;
  final String? title;
  final TextStyle? titleStyle;
  final Key? closeKey;
  final double buttonSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: buttonSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (title != null)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: buttonSize),
                  child: Text(
                    title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: titleStyle ?? Heading5.style,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: closeKey,
                tooltip: tr(context, 'Close'),
                onPressed: onClose,
                padding: EdgeInsets.all((buttonSize - iconSize) / 2),
                constraints: BoxConstraints.tightFor(
                  width: buttonSize,
                  height: buttonSize,
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  Icons.close,
                  size: iconSize,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      );
}
