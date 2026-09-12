// SQL table: user_profiles
// user_id | favorite_team_id | pts | post_count | comment_count | created_at | updated_at
// Note: pts, post_count, comment_count not yet in live schema — added for UI dev

class UserProfile {
  final int userId;
  final int? favoriteTeamId;
  final int pts;
  final int postCount;
  final int commentCount;
  final String createdAt;
  final String updatedAt;

  const UserProfile({
    required this.userId,
    this.favoriteTeamId,
    this.pts = 0,
    this.postCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId:         json['user_id'] as int,
      favoriteTeamId: json['favorite_team_id'] as int?,
      pts:            json['pts'] as int? ?? 0,
      postCount:      json['post_count'] as int? ?? 0,
      commentCount:   json['comment_count'] as int? ?? 0,
      createdAt:      json['created_at'] as String,
      updatedAt:      json['updated_at'] as String,
    );
  }
}