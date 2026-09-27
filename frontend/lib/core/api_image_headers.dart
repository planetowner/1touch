import 'package:onetouch/core/api_client_provider.dart';

Map<String, String>? apiImageHeaders(String imageUrl) {
  final imageUri = Uri.tryParse(imageUrl);
  if (imageUri == null ||
      imageUri.scheme != apiClient.baseUri.scheme ||
      imageUri.host != apiClient.baseUri.host ||
      imageUri.port != apiClient.baseUri.port) {
    return null;
  }

  final headers = authSession.requestHeaders;
  return headers.isEmpty ? null : headers;
}
