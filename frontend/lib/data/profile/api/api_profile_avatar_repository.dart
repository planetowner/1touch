import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/profile/profile_avatar_repository.dart';

class ApiProfileAvatarRepository implements ProfileAvatarRepository {
  ApiProfileAvatarRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

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

    final uri = _apiBaseUri.resolve('users/me/avatar');
    final request = http.MultipartRequest('PUT', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        ..._requestHeaders,
      })
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: normalizedFilename,
        ),
      );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Avatar upload failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the avatar-upload response to be a JSON object.',
      );
    }
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
        parsed.isAbsolute ? parsed : _apiBaseUri.resolveUri(parsed);
    if ((resolved.scheme != 'http' && resolved.scheme != 'https') ||
        resolved.host.isEmpty) {
      throw FormatException('Invalid avatar_url: $avatarUrl');
    }
    return resolved;
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
