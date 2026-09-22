import 'package:onetouch/core/api_config.dart';
import 'package:onetouch/data/post_attachments/api/api_post_attachment_repository.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';

final ApiConfig _apiConfig = ApiConfig.unauthenticatedFromEnvironment();

final PostAttachmentRepository postAttachmentRepository =
    ApiPostAttachmentRepository(
  client: ApiConfig.sessionAwareClient(),
  apiBaseUri: _apiConfig.baseUri,
  requestHeaders: _apiConfig.requestHeaders,
);
