// SQL table: user_following_teams
// user_id | team_id | created_at

class UserFollowingTeam {
  final int userId;
  final int teamId;
  final String createdAt;

  const UserFollowingTeam({
    required this.userId,
    required this.teamId,
    required this.createdAt,
  });

  factory UserFollowingTeam.fromJson(Map<String, dynamic> json) {
    return UserFollowingTeam(
      userId:    json['user_id'] as int,
      teamId:    json['team_id'] as int,
      createdAt: json['created_at'] as String,
    );
  }
}