enum PostCommentState { active, deleted, hidden, blocked }

class PostComment {
  const PostComment({
    required this.commentId,
    required this.postId,
    required this.userId,
    required this.replyToId,
    required this.body,
    required this.createdAt,
    required this.editedAt,
    required this.state,
    required this.username,
    required this.avatarUrl,
    required this.authorDeleted,
    required this.likeCount,
    required this.liked,
  });

  final int commentId;
  final int postId;
  final int? userId;
  final int? replyToId;
  final String body;
  final String createdAt;
  final String? editedAt;
  final PostCommentState state;
  final String? username;
  final String? avatarUrl;
  final bool authorDeleted;
  final int likeCount;
  final bool liked;
}
