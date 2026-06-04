// SQL table: posts
// post_id | user_id | category | title | body | media_url | created_at | updated_at

enum PostCategory { general, analysis, news }

class Post {
  final int postId;
  final int userId;
  final PostCategory category;
  final String title;
  final String body;
  final String? mediaUrl;
  final String createdAt; // timestamp string
  final String updatedAt;

  const Post({
    required this.postId,
    required this.userId,
    required this.category,
    required this.title,
    required this.body,
    this.mediaUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      postId:    json['post_id'] as int,
      userId:    json['user_id'] as int,
      category:  _parseCategory(json['category'] as String? ?? 'general'),
      title:     json['title'] as String,
      body:      json['body'] as String,
      mediaUrl:  json['media_url'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
    );
  }

  static PostCategory _parseCategory(String raw) {
    switch (raw) {
      case 'analysis': return PostCategory.analysis;
      case 'news':     return PostCategory.news;
      default:         return PostCategory.general;
    }
  }
}