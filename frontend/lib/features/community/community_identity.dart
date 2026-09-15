/// Canonical public identity used for posts, comments, replies, and reactions.
String communityUsernameLabel({
  required String? username,
  required bool authorDeleted,
}) {
  if (authorDeleted) return 'Deleted user';

  final normalizedUsername = username?.trim();
  if (normalizedUsername == null || normalizedUsername.isEmpty) {
    return 'Unknown user';
  }
  return '@$normalizedUsername';
}
