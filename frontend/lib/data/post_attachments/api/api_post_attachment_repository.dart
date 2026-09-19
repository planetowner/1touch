import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:onetouch/data/post_attachments/api/api_post_attachment_response.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/models/uploaded_post_attachment.dart';

class ApiPostAttachmentRepository implements PostAttachmentRepository {
  ApiPostAttachmentRepository({
    required http.Client client,
    required Uri apiBaseUri,
    required Map<String, String> requestHeaders,
  })  : _client = client,
        _apiBaseUri = _asDirectoryUri(apiBaseUri),
        _requestHeaders = Map.unmodifiable(requestHeaders);

  static const _allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/webm',
  };

  final http.Client _client;
  final Uri _apiBaseUri;
  final Map<String, String> _requestHeaders;

  @override
  Future<UploadedPostAttachment> upload({
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

    final uri = _apiBaseUri.resolve('attachments/upload');
    final request = http.MultipartRequest('POST', uri)
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
    if (response.statusCode != 201) {
      throw http.ClientException(
        'Post attachment upload failed with status ${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Expected the attachment-upload response to be a JSON object.',
      );
    }
    final apiResponse = ApiPostAttachmentUploadResponse.fromJson(decoded);
    final contentType = apiResponse.contentType.trim().toLowerCase();
    if (apiResponse.attachmentId < 1 ||
        apiResponse.byteSize != bytes.length ||
        !_allowedContentTypes.contains(contentType)) {
      throw const FormatException(
        'Invalid attachment-upload response metadata.',
      );
    }

    return UploadedPostAttachment(
      attachmentId: apiResponse.attachmentId,
      contentType: contentType,
      byteSize: apiResponse.byteSize,
    );
  }

  @override
  Future<void> delete(int attachmentId) async {
    if (attachmentId < 1) {
      throw RangeError.value(
        attachmentId,
        'attachmentId',
        'must be positive',
      );
    }

    final uri = _apiBaseUri.resolve('attachments/$attachmentId');
    final response = await _client.delete(
      uri,
      headers: {
        'Accept': 'application/json',
        ..._requestHeaders,
      },
    );
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Post attachment deletion failed with status '
        '${response.statusCode}.',
        uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
      throw const FormatException(
        'Expected ok=true in the attachment-deletion response.',
      );
    }
  }

  static Uri _asDirectoryUri(Uri uri) {
    final value = uri.toString();
    return value.endsWith('/') ? uri : Uri.parse('$value/');
  }
}
