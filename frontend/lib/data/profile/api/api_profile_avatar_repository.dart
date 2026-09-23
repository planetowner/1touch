import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/profile/profile_avatar_repository.dart';

class ApiProfileAvatarRepository implements ProfileAvatarRepository {
  ApiProfileAvatarRepository({required ApiClient api}) : _api = api;

  final ApiClient _api;

  @override
  Future<Uri> upload({
    required Uint8List bytes,
    required String filename,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'must not be empty');
    }
    final normalizedFilename = filename.trim();
    if (normalizedFilename.isEmpty) {
      throw ArgumentError.value(filename, 'filename', 'must not be empty');
    }

    final uri = _api.baseUri.resolve('users/me/avatar');
    final request = http.MultipartRequest('PUT', uri)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: normalizedFilename,
        ),
      );
    final response = await http.Response.fromStream(
      await _api.send(request),
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    final avatarUrl = decoded['avatar_url'];
    if (avatarUrl is! String || avatarUrl.trim().isEmpty) {
      throw const FormatException(
        'Expected avatar_url in the avatar-upload response.',
      );
    }

    final parsed = Uri.tryParse(avatarUrl.trim());
    if (parsed == null) {
      throw FormatException('Invalid avatar_url: $avatarUrl');
    }
    final resolved =
        parsed.isAbsolute ? parsed : _api.baseUri.resolveUri(parsed);
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty) {
      throw FormatException('Invalid avatar_url: $avatarUrl');
    }
    return resolved;
  }

  @override
  Future<void> delete() async {
    final uri = _api.baseUri.resolve('users/me/avatar');
    final response = await _api.delete(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException(
        'Expected ok=true in the avatar-deletion response.',
      );
    }
  }
}
