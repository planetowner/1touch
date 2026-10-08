import 'package:onetouch/core/api_json.dart' as api_json;

class ApiPostAttachmentUploadResponse {
  const ApiPostAttachmentUploadResponse({
    required this.attachmentId,
    required this.contentType,
    required this.byteSize,
  });

  final int attachmentId;
  final String contentType;
  final int byteSize;

  factory ApiPostAttachmentUploadResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return ApiPostAttachmentUploadResponse(
      attachmentId: api_json.requiredInt(json, 'attachment_id'),
      contentType: api_json.requiredString(json, 'content_type'),
      byteSize: api_json.requiredInt(json, 'byte_size'),
    );
  }
}
