class TeamFeatureUnavailableException implements Exception {
  const TeamFeatureUnavailableException({
    required this.teamId,
    required this.feature,
  });

  final int teamId;
  final String feature;

  @override
  String toString() => '$feature is unavailable for team $teamId.';
}
