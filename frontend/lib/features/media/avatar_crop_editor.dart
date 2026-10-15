import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:insta_assets_crop/insta_assets_crop.dart';

/// 같은 크롭 위젯을 유지해 목록을 접었다 펴도 확대·이동 상태가 사라지지 않아요.
class AvatarCropEditor extends StatelessWidget {
  const AvatarCropEditor({
    super.key,
    required this.cropKey,
    required this.imageSize,
    required this.image,
  });

  final GlobalKey<CropState> cropKey;
  final Size imageSize;
  final Widget image;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: const _CircleShade(),
        child: Crop(
          key: cropKey,
          size: imageSize,
          aspectRatio: 1,
          disableResize: true,
          maximumScale: 8,
          child: image,
        ),
      );
}

class _CircleShade extends CustomPainter {
  const _CircleShade();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(bounds)
      ..addOval(bounds);
    canvas.drawPath(path, Paint()..color = const Color(0x73000000));
  }

  @override
  bool shouldRepaint(_CircleShade oldDelegate) => false;
}

/// 원형은 미리보기 마스크이고, 업로드는 기존 규격의 정사각형 사진을 사용해요.
Future<XFile> exportAvatarCrop(File original, Rect area) async {
  final sampled =
      await InstaAssetsCrop.sampleImage(file: original, preferredSize: 1080);
  try {
    final cropped = await InstaAssetsCrop.cropImage(file: sampled, area: area);
    return XFile(cropped.path, mimeType: 'image/jpeg');
  } finally {
    if (sampled.path != original.path) {
      try {
        await sampled.delete();
      } on FileSystemException {
        // 임시 파일 정리에 실패해도 내보낸 사진은 사용할 수 있어요.
      }
    }
  }
}
