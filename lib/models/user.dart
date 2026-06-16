// SQL table: users
// user_id | display_name | username | email | avatar_asset | created_at
// Note: display_name, username, email, avatar_asset not yet in live schema — added for UI dev

class User {
  final int userId;
  final String displayName;
  final String username;
  final String email;
  final String? avatarAsset; // local asset path, e.g. 'assets/profileavatar.png'
  final String createdAt;

  const User({
    required this.userId,
    required this.displayName,
    required this.username,
    required this.email,
    this.avatarAsset,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId:      json['user_id'] as int,
      displayName: json['display_name'] as String,
      username:    json['username'] as String,
      email:       json['email'] as String,
      avatarAsset: json['avatar_asset'] as String?,
      createdAt:   json['created_at'] as String,
    );
  }
}