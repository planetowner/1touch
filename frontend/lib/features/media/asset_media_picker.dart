import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/features/media/media_picker_screen.dart';

/// 사진 목록과 크롭을 같은 화면에서 조절한 뒤 기존 업로드로 넘겨요.
Future<XFile?> pickAvatarImage(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(builder: (_) => const MediaPickerScreen()),
    );

/// 공통 선택기에서 고른 사진·동영상을 자르지 않고 첨부 흐름으로 넘겨요.
Future<List<XFile>> pickAssetMedia(
  BuildContext context, {
  required int maxAssets,
}) async {
  return await Navigator.of(context, rootNavigator: true).push<List<XFile>>(
        MaterialPageRoute(
            builder: (_) =>
                MediaPickerScreen.attachments(maxAssets: maxAssets)),
      ) ??
      [];
}
