// SQL table: users
// user_id | created_at

class User {
  final int userId;
  final String createdAt; // timestamp string

  const User({
    required this.userId,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId:    json['user_id'] as int,
      createdAt: json['created_at'] as String,
    );
  }
}