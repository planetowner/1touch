class CurrentUserProfile {
  const CurrentUserProfile({
    required this.userId,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.avatarUri,
    required this.favoriteTeamId,
    required this.createdAt,
  });

  final int userId;
  final String username;
  final String firstName;
  final String lastName;
  final String? email;
  final Uri? avatarUri;
  final int favoriteTeamId;
  final DateTime createdAt;

  String get displayName => '$firstName $lastName';
}
