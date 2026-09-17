import 'dart:typed_data';

abstract interface class ProfileAvatarRepository {
  Future<Uri> upload({
    required Uint8List bytes,
    required String filename,
  });
}
