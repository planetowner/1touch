import 'package:onetouch/core/api_client_provider.dart';
import 'package:onetouch/data/post_attachments/api/api_post_attachment_repository.dart';
import 'package:onetouch/data/post_attachments/post_attachment_repository.dart';

final PostAttachmentRepository postAttachmentRepository =
    ApiPostAttachmentRepository(
  api: apiClient,
);
