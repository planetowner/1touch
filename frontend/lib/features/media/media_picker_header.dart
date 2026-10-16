import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/l10n/app_localizations.dart';

/// 프로필과 첨부 선택기는 같은 헤더를 쓰고 제목과 완료 동작만 바꿔요.
class MediaPickerHeader extends StatelessWidget {
  const MediaPickerHeader({
    super.key,
    required this.onCancel,
    required this.onDone,
    required this.saving,
    this.title = 'Profile Photo',
  });

  final VoidCallback? onCancel;
  final VoidCallback? onDone;
  final bool saving;
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
        key: const ValueKey('avatar-picker-header'),
        height: 56,
        // 아이콘은 시안의 24px 위치에 두고, 누를 수 있는 영역은 48px로 유지해요.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            _HeaderButton(
                buttonKey: const ValueKey('media-picker-cancel'),
                asset: 'close',
                label: tr(context, 'Cancel'),
                onPressed: onCancel),
            Expanded(
              child: Center(
                child: saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(tr(context, title),
                        // Archivo 파일의 기본 굵기 600 대신 시안의 Regular를 써요.
                        style: Body1.style.copyWith(
                            fontVariations: const [FontVariation.weight(400)],
                            letterSpacing: 0,
                            height: 1.3),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
              ),
            ),
            _HeaderButton(
                buttonKey: const ValueKey('media-picker-done'),
                asset: 'check',
                label: tr(context, 'Done'),
                onPressed: onDone),
          ]),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.buttonKey,
    required this.asset,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String asset;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        key: buttonKey,
        onPressed: onPressed,
        tooltip: label,
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        icon: SvgPicture.asset('assets/media_picker/$asset.svg',
            colorFilter: ColorFilter.mode(
                onPressed == null
                    ? Theme.of(context).disabledColor
                    : Theme.of(context).colorScheme.onSurface,
                BlendMode.srcIn)),
      );
}
