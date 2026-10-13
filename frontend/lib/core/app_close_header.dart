import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 시트와 팝업이 제목과 닫기 버튼을 공유해요. 바깥 여백은 사용하는 곳에서 정해요.
class AppCloseHeader extends StatelessWidget {
  const AppCloseHeader({
    super.key,
    required this.onClose,
    this.title,
    this.titleStyle,
    this.titleAlignment = TextAlign.center,
    this.closeKey,
    this.buttonSize = 48,
    this.iconSize = 24,
    this.closeAlignment = Alignment.centerRight,
  });

  final VoidCallback onClose;
  final String? title;
  final TextStyle? titleStyle;
  final TextAlign titleAlignment;
  final Key? closeKey;
  final double buttonSize;
  final double iconSize;
  final AlignmentGeometry closeAlignment;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        // 한글 제목의 줄 높이가 닫기 버튼보다 커도 본문과 겹치지 않게 해요.
        constraints: BoxConstraints(minHeight: buttonSize),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (title != null && titleAlignment == TextAlign.center)
              SizedBox(width: buttonSize),
            if (title != null)
              Expanded(
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: titleAlignment,
                  style: titleStyle ?? Heading5.style,
                ),
              ),
            IconButton(
              key: closeKey,
              tooltip: tr(context, 'Close'),
              onPressed: onClose,
              padding: closeAlignment == Alignment.center
                  ? EdgeInsets.all((buttonSize - iconSize) / 2)
                  : EdgeInsets.zero,
              // 터치 영역을 유지하면서 아이콘 끝을 바깥 패딩에 맞춰요.
              alignment: closeAlignment,
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
          ],
        ),
      );
}
