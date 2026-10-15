import 'dart:io';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:photo_manager/photo_manager.dart';

/// 사진 접근만 네이티브 API에 맡기고, 목록과 선택 상태는 공통 화면에서 관리해요.
class AvatarPhotoLibrary {
  const AvatarPhotoLibrary();

  static const pageSize = 80;
  static const permission = PermissionRequestOption(
    androidPermission:
        AndroidPermission(type: RequestType.image, mediaLocation: false),
  );

  Future<PermissionState> requestAccess() =>
      PhotoManager.requestPermissionExtend(requestOption: permission);

  Future<PermissionState> access() =>
      PhotoManager.getPermissionState(requestOption: permission);

  Future<List<AssetPathEntity>> albums() => PhotoManager.getAssetPathList(
        type: RequestType.image,
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

  Future<File?> takePhoto() async {
    final photo = await ImagePicker().pickImage(source: ImageSource.camera);
    return photo == null ? null : File(photo.path);
  }

  Future<void> manageAccess() =>
      PhotoManager.presentLimited(type: RequestType.image);

  Future<void> openSettings() => PhotoManager.openSetting();
}
