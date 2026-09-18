import 'package:flutter/foundation.dart';

@immutable
class TeamProbabilityCard {
  const TeamProbabilityCard({
    required this.event,
    required this.competitionId,
    required this.category,
    required this.probability,
    required this.changePercentagePoints,
    required this.entropy,
  });

  final String event;
  final int competitionId;
  final String category;

  /// A backend probability in the inclusive range 0–1.
  final double probability;

  /// Change from the backend comparison snapshot, measured in percentage
  /// points. Null means that no valid comparison snapshot exists.
  final double? changePercentagePoints;
  final double? entropy;
}

@immutable
class TeamProbabilityComparison {
  const TeamProbabilityComparison({
    required this.available,
    required this.asOf,
  });

  final bool available;
  final DateTime? asOf;
}

@immutable
class TeamProbabilitySnapshot {
  TeamProbabilitySnapshot({
    required this.teamId,
    required this.teamName,
    required this.competitionId,
    required this.seasonId,
    required this.seasonName,
    required this.asOf,
    required this.comparison,
    required List<TeamProbabilityCard> cards,
    required List<String> pendingOutcomes,
  })  : cards = List.unmodifiable(cards),
        pendingOutcomes = List.unmodifiable(pendingOutcomes);

  final int teamId;
  final String teamName;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final DateTime asOf;
  final TeamProbabilityComparison comparison;
  final List<TeamProbabilityCard> cards;
  final List<String> pendingOutcomes;
}
