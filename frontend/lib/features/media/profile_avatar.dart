import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.child,
    this.onEdit,
    this.actionKey,
    this.isSaving = false,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final Key? actionKey;
  final bool isSaving;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          child,
          if (onEdit != null)
            // Figma처럼 사진의 오른쪽 아래에 버튼을 조금 겹쳐 배치해요.
            Positioned(
              right: -4.5,
              bottom: -4,
              child: SizedBox.square(
                dimension: 48,
                child: IconButton.filled(
                  key: actionKey,
                  onPressed: isSaving ? null : onEdit,
                  style: IconButton.styleFrom(
                    backgroundColor: AppPalette.lightGrey,
                    disabledBackgroundColor: AppPalette.lightGrey,
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: isSaving
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppPalette.white,
                          ),
                        )
                      : SvgPicture.asset(
                          'assets/community/camera.svg',
                          width: 24,
                          height: 24,
                        ),
                ),
              ),
            ),
        ],
      );
}
