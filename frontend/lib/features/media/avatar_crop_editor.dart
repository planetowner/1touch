import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Crop(
            key: cropKey,
            size: imageSize,
            aspectRatio: 1,
            disableResize: true,
            maximumScale: 8,
            child: image,
          ),
          IgnorePointer(
            child: FittedBox(
              child: SvgPicture.asset('assets/media_picker/crop_mask.svg'),
            ),
          ),
        ],
      );
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
