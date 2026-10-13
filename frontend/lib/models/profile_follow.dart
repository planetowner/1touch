enum ProfileFollowTab { followers, following }

enum ProfileFollowSort { newest, oldest }

class ProfileFollowCounts {
  const ProfileFollowCounts({required this.followers, required this.following});
  final int followers;
  final int following;
}

class ProfileFollowUser {
  const ProfileFollowUser({
    required this.userId,
    required this.name,
    this.avatarUri,
  });
  final int userId;
  final String name;
  final Uri? avatarUri;
}
