import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:onetouch/core/api_client.dart';
import 'package:onetouch/data/post_attachments/api/api_post_attachment_response.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';
import 'package:onetouch/models/uploaded_post_attachment.dart';

class ApiPostAttachmentRepository implements PostAttachmentRepository {
  ApiPostAttachmentRepository({required ApiClient api}) : _api = api;

  static const _allowedContentTypes = {
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp',
    'video/mp4',
    'video/webm',
  };

  final ApiClient _api;

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

    final uri = _api.baseUri.resolve('attachments/upload');
    final request = http.MultipartRequest('POST', uri)
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

    final decoded =
        _api.decodeJson<Map<String, dynamic>>(response, expectedStatus: 201);
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

    final uri = _api.baseUri.resolve('attachments/$attachmentId');
    final response = await _api.delete(
      uri,
    );

    final decoded = _api.decodeJson<Map<String, dynamic>>(response);
    if (decoded['ok'] != true) {
      throw const FormatException(
        'Expected ok=true in the attachment-deletion response.',
      );
    }
  }
}
