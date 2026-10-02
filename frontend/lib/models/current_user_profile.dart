class CurrentUserProfile {
  const CurrentUserProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.avatarUri,
    required this.favoriteTeamId,
    required this.createdAt,
    this.socialAccounts = const {},
  });

  final int userId;
  final String username;
  final String? displayName;
  final String firstName;
  final String lastName;
  final String? email;
  final Uri? avatarUri;
  final int favoriteTeamId;
  final DateTime createdAt;
  final Set<String> socialAccounts;

  // 닉네임을 아직 정하지 않은 기존 회원은 설정 전까지 아이디를 보여줘요.
  String get profileHeading => '@${displayName ?? username}';
}
