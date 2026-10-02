class CurrentUserProfile {
  const CurrentUserProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.email,
    required this.avatarUri,
    required this.favoriteTeamId,
    required this.createdAt,
    this.socialAccounts = const {},
  });

  final int userId;
  final String? username;
  final String displayName;
  final String? email;
  final Uri? avatarUri;
  final int favoriteTeamId;
  final DateTime createdAt;
  final Set<String> socialAccounts;

  String get profileHeading => '@$displayName';
}
