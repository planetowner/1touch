import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// 파일 접근은 네이티브 API에 맡기고, 목록과 선택 상태는 공통 화면에서 관리해요.
class MediaLibrary {
  const MediaLibrary({this.type = RequestType.image});

  final RequestType type;

  static const pageSize = 80;
  PermissionRequestOption get _permission => PermissionRequestOption(
        androidPermission: AndroidPermission(type: type, mediaLocation: false),
      );

  Future<PermissionState> requestAccess() =>
      PhotoManager.requestPermissionExtend(requestOption: _permission);

  Future<PermissionState> access() =>
      PhotoManager.getPermissionState(requestOption: _permission);

  Future<List<AssetPathEntity>> albums() => PhotoManager.getAssetPathList(
        type: type,
        filterOption: FilterOptionGroup(
          orders: [const OrderOption(type: OrderOptionType.createDate)],
        ),
      );

  Future<List<AssetEntity>> photos(AssetPathEntity album, int page) =>
      album.getAssetListPaged(page: page, size: pageSize);

  Future<Uint8List?> thumbnail(AssetEntity photo, {int size = 240}) =>
      photo.thumbnailDataWithOption(Platform.isIOS || Platform.isMacOS
          ? ThumbnailOption.ios(
              size: ThumbnailSize.square(size),
              quality: 85,
              // 목록 이미지를 크롭에서도 재사용하므로 원래 구도를 유지해요.
              resizeContentMode: ResizeContentMode.fit,
            )
          : ThumbnailOption(size: ThumbnailSize.square(size), quality: 85));

  Future<File?> file(AssetEntity photo) => photo.file;

  Future<XFile> attachment(AssetEntity asset) async {
    // 썸네일이나 크롭 결과 대신 전체 파일을 기존 첨부 흐름으로 넘겨요.
    final original = await asset.originFile;
    if (original == null) throw const FileSystemException('Media unavailable');
    if (Platform.isIOS) {
      // 기존 시스템 선택기와 같은 변환 규칙으로 HEIC와 GIF도 처리해요.
      final prepared = await const MethodChannel('onetouch/media_picker')
          .invokeMapMethod<String, String>('prepare', {
        'path': original.path,
        'isVideo': asset.type == AssetType.video,
      });
      return XFile(prepared!['path']!, mimeType: prepared['mimeType']);
    }
    return XFile(original.path, mimeType: await asset.mimeTypeAsync);
  }

  Future<File?> takePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    return photo == null ? null : File(photo.path);
  }

  Future<void> manageAccess() => PhotoManager.presentLimited(type: type);

  Future<void> openSettings() => PhotoManager.openSetting();
}
