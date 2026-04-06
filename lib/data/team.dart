class TeamOut {
  final int teamId;
  final String name;
  final String? shortCode;
  final String? imagePath;

  const TeamOut({
    required this.teamId,
    required this.name,
    this.shortCode,
    this.imagePath,
  });
}