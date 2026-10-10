import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:insta_assets_picker/insta_assets_picker.dart';
import 'package:onetouch/features/media/avatar_crop_screen.dart';

/// A single tap returns from the gallery and opens the avatar crop screen.
Future<XFile?> pickAvatarImage(BuildContext context) async {
  final selected = await AssetPicker.pickAssets(
    context,
    pickerConfig: AssetPickerConfig(
      maxAssets: 1,
      requestType: RequestType.image,
      specialPickerType: SpecialPickerType.noPreview,
      textDelegate: InstaAssetPicker.defaultTextDelegate(context),
    ),
  );
  if (!context.mounted || selected == null || selected.isEmpty) return null;

  final asset = selected.single;
  final original = await asset.originFile;
  if (!context.mounted) return null;
  if (original == null) throw StateError('Unable to open selected photo.');

  return Navigator.of(context, rootNavigator: true).push<XFile>(
    MaterialPageRoute(
      builder: (_) => AvatarCropScreen(
        originalFile: original,
        imageSize: asset.orientatedSize,
        image: Image(image: AssetEntityImageProvider(asset, isOriginal: true)),
      ),
    ),
  );
}

/// 공통 갤러리를 열고 선택한 순서대로 파일을 반환해요.
Future<List<XFile>> pickAssetMedia(
  BuildContext context, {
  required int maxAssets,
  RequestType requestType = RequestType.common,
}) async {
  // 목록 썸네일에서만 잘라 보여 주고, 첨부 파일에는 사진 전체를 보존해요.
  final selected = await AssetPicker.pickAssets(
    context,
    pickerConfig: AssetPickerConfig(
      maxAssets: maxAssets,
      requestType: requestType,
      textDelegate: InstaAssetPicker.defaultTextDelegate(context),
    ),
  );
  if (selected == null || selected.isEmpty) return [];

  final files = <XFile>[];
  for (final asset in selected) {
    // iOS의 file은 사진 전체 크기를 유지한 JPEG라 HEIC도 서버에 올릴 수 있어요.
    final file = asset.type == AssetType.image
        ? await asset.file
        : await asset.originFile;
    if (file == null) {
      throw StateError('Unable to export selected media.');
    }
    files.add(XFile(file.path,
        mimeType: asset.type == AssetType.video ? 'video/*' : null));
  }
  return files;
}
