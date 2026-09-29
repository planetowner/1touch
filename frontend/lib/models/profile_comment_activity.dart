import 'package:onetouch/models/post.dart';
import 'package:onetouch/models/post_comment.dart';

class ProfileCommentActivity {
  const ProfileCommentActivity({required this.post, required this.comment});

  final Post post;
  final PostComment comment;
}
