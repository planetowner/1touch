// GET /v1/posts item contract:
// post_id | team_id | user_id | category | title | body | media_url | created_at

// 탭과 글쓰기에서 같은 분류 순서와 이름을 사용해요. enum 이름은 API 값이에요.
enum PostCategory {
  general('General'),
  analysis('Analysis'),
  news('News & Insights'),
  fanart('Fan Art');

  const PostCategory(this.label);

  final String label;

  static PostCategory? tryParse(String raw) =>
      values.where((category) => category.name == raw).firstOrNull;
}

class PostAttachment {
  final int attachmentId;
  final int position;
  final String? linkUrl;
  final String? mediaUrl;
  final String? contentType;
  final int? byteSize;

  const PostAttachment({
    required this.attachmentId,
    required this.position,
    this.linkUrl,
    this.mediaUrl,
    this.contentType,
    this.byteSize,
  });
}

class Post {
  final int postId;
  final int teamId;
  final int? userId;
  final PostCategory category;
  final String title;
  final String body;
  final String? mediaUrl;
  final String createdAt; // timestamp string
  final String? editedAt;
  final String? username;
  final String? avatarUrl;
  final bool authorDeleted;
  final int likeCount;
  final int commentCount;
  final bool liked;
  final List<PostAttachment> attachments;

  const Post({
    required this.postId,
    required this.teamId,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    this.mediaUrl,
    required this.createdAt,
    this.editedAt,
    this.username,
    this.avatarUrl,
    this.authorDeleted = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.liked = false,
    this.attachments = const [],
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      postId: json['post_id'] as int,
      teamId: json['team_id'] as int,
      userId: json['user_id'] as int?,
      category: PostCategory.tryParse(json['category'] as String? ?? '') ??
          PostCategory.general,
      title: json['title'] as String,
      body: json['body'] as String,
      mediaUrl: json['media_url'] as String?,
      createdAt: json['created_at'] as String,
      editedAt: json['edited_at'] as String?,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      authorDeleted: json['author_deleted'] as bool? ?? false,
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      liked: json['liked'] as bool? ?? false,
    );
  }
}
