class CommunityProfile {
  const CommunityProfile(
      {required this.userId,
      this.username,
      this.displayName,
      this.avatarUri,
      required this.isSelf,
      this.following = false});
  final int userId;
  final String? username, displayName;
  final Uri? avatarUri;
  final bool isSelf, following;
}
