import 'package:onetouch/models/post.dart';

class PostDraft {
  const PostDraft(
      {required this.postId,
      required this.teamId,
      required this.language,
      required this.category,
      required this.title,
      required this.body,
      required this.attachments,
      required this.expiresAt});
  final int postId, teamId;
  final String language, title, body;
  final PostCategory category;
  final List<PostAttachment> attachments;
  final DateTime expiresAt;
}
