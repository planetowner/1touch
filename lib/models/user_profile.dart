// SQL table: user_profiles
// user_id | favorite_team_id | created_at | updated_at

class UserProfile {
  final int userId;
  final int? favoriteTeamId; // nullable — user may not have set a favorite
  final String createdAt;
  final String updatedAt;

  const UserProfile({
    required this.userId,
    this.favoriteTeamId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId:         json['user_id'] as int,
      favoriteTeamId: json['favorite_team_id'] as int?,
      createdAt:      json['created_at'] as String,
      updatedAt:      json['updated_at'] as String,
    );
  }
}