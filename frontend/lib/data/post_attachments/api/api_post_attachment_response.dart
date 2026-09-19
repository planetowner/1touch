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
      attachmentId: _requiredInt(json, 'attachment_id'),
      contentType: _requiredString(json, 'content_type'),
      byteSize: _requiredInt(json, 'byte_size'),
    );
  }
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw FormatException('Expected required integer field "$key".');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('Expected required string field "$key".');
}
