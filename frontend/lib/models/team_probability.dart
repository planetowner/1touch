import 'package:flutter/foundation.dart';

enum ProbabilityResolution { unresolved, impossible, certain }

@immutable
class TeamProbabilityCard {
  const TeamProbabilityCard({
    required this.event,
    required this.competitionId,
    required this.category,
    required this.probability,
    required this.changePercentagePoints,
    required this.entropy,
    this.resolution = ProbabilityResolution.unresolved,
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
  final ProbabilityResolution resolution;
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
class TeamPositionProbability {
  const TeamPositionProbability({
    required this.position,
    required this.probability,
  });

  final int position;
  final double probability;
}

@immutable
class TeamPointsInterval {
  const TeamPointsInterval({
    required this.lower,
    required this.upper,
  });

  final int lower;
  final int upper;
}

@immutable
class TeamProjectedPoints {
  const TeamProjectedPoints({
    required this.mean,
    required this.likelyRange,
    required this.changePoints,
  });

  final double mean;
  final TeamPointsInterval likelyRange;
  final double? changePoints;
}

@immutable
class TeamProbabilityHistoryPoint {
  TeamProbabilityHistoryPoint({
    required this.asOf,
    required this.played,
    required List<TeamProbabilityCard> events,
    required this.expectedPoints,
  }) : events = List.unmodifiable(events);

  final DateTime asOf;
  final int played;
  final List<TeamProbabilityCard> events;
  final double expectedPoints;

  TeamProbabilityCard? event(String eventName) {
    for (final item in events) {
      if (item.event == eventName) return item;
    }
    return null;
  }
}

@immutable
class TeamProbabilityWhatIfFixture {
  TeamProbabilityWhatIfFixture({
    required this.fixtureId,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.startingAt,
    required this.roundName,
    required List<double> probabilities,
  }) : probabilities = List.unmodifiable(probabilities);

  final int fixtureId;
  final int homeTeamId;
  final int awayTeamId;
  final DateTime startingAt;
  final String? roundName;

  /// Home win, draw, and away win probabilities, in that order.
  final List<double> probabilities;
}

@immutable
class TeamProbabilityWhatIfScenario {
  TeamProbabilityWhatIfScenario({
    required this.outcome,
    required List<TeamProbabilityCard> events,
    required List<TeamPositionProbability> positions,
    required this.projectedPoints,
  })  : events = List.unmodifiable(events),
        positions = List.unmodifiable(positions);

  final String outcome;
  final List<TeamProbabilityCard> events;
  final List<TeamPositionProbability> positions;
  final TeamProjectedPoints projectedPoints;

  TeamProbabilityCard? event(String eventName) {
    for (final item in events) {
      if (item.event == eventName) return item;
    }
    return null;
  }
}

@immutable
class TeamProbabilityWhatIf {
  TeamProbabilityWhatIf({
    required this.fixture,
    required List<TeamProbabilityWhatIfScenario> scenarios,
  }) : scenarios = List.unmodifiable(scenarios);

  final TeamProbabilityWhatIfFixture fixture;
  final List<TeamProbabilityWhatIfScenario> scenarios;
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
    required this.maximumPoints,
    required List<TeamPositionProbability> positions,
    required this.projectedPoints,
    required this.comparison,
    required List<TeamProbabilityCard> cards,
    required List<TeamProbabilityHistoryPoint> history,
    required List<String> pendingOutcomes,
    this.whatIf,
  })  : positions = List.unmodifiable(positions),
        cards = List.unmodifiable(cards),
        history = List.unmodifiable(history),
        pendingOutcomes = List.unmodifiable(pendingOutcomes);

  final int teamId;
  final String teamName;
  final int competitionId;
  final int seasonId;
  final String seasonName;
  final DateTime asOf;
  final int maximumPoints;
  final List<TeamPositionProbability> positions;
  final TeamProjectedPoints projectedPoints;
  final TeamProbabilityComparison comparison;
  final List<TeamProbabilityCard> cards;
  final List<TeamProbabilityHistoryPoint> history;
  final List<String> pendingOutcomes;
  final TeamProbabilityWhatIf? whatIf;
}
