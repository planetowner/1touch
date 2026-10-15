import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:onetouch/features/media/avatar_picker_screen.dart';

const _channel = MethodChannel('onetouch/media_picker');

/// 사진 목록과 크롭을 같은 화면에서 조절한 뒤 기존 업로드로 넘겨요.
Future<XFile?> pickAvatarImage(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<XFile>(
      MaterialPageRoute(builder: (_) => const AvatarPickerScreen()),
    );

/// 시스템에서 고른 사진·동영상을 자르지 않고 첨부 흐름으로 넘겨요.
Future<List<XFile>> pickAssetMedia(
  BuildContext context, {
  required int maxAssets,
}) async {
  final selected = await _channel.invokeListMethod<dynamic>('pick', {
    'maxAssets': maxAssets,
    'imagesOnly': false,
  });
  return [
    for (final file in selected ?? const [])
      XFile(file['path'] as String, mimeType: file['mimeType'] as String),
  ];
}
