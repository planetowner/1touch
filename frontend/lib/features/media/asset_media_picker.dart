import 'dart:async';

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

/// Opens the shared gallery picker and returns files in selection order.
Future<List<XFile>> pickAssetMedia(
  BuildContext context, {
  required int maxAssets,
  RequestType requestType = RequestType.common,
  List<double> cropRatios = kDefaultInstaCropRatios,
}) async {
  final export = Completer<InstaAssetsExportDetails>();
  final selected = await InstaAssetPicker.pickAssets(
    context,
    maxAssets: maxAssets,
    requestType: requestType,
    pickerConfig: InstaAssetPickerConfig(
      closeOnComplete: true,
      cropDelegate: InstaAssetCropDelegate(cropRatios: cropRatios),
    ),
    onCompleted: (stream) => export.complete(stream.last),
  );
  if (selected == null || selected.isEmpty) return [];

  final details = await export.future;
  if (details.data.length != selected.length) {
    throw StateError('Unable to export all selected media.');
  }
  final files = <XFile>[];
  for (final item in details.data) {
    final asset = item.selectedData.asset;
    final file = asset.type == AssetType.image
        ? item.croppedFile
        : await asset.originFile;
    if (file == null) {
      throw StateError('Unable to export selected media.');
    }
    files.add(XFile(file.path));
  }
  return files;
}
