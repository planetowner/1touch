import 'package:onetouch/data/team_probability/api/api_team_probability_response.dart';
import 'package:onetouch/models/team_probability.dart';

TeamProbabilitySnapshot teamProbabilityFromApiResponse(
  ApiTeamProbabilityResponse response,
) {
  return TeamProbabilitySnapshot(
    teamId: response.teamId,
    teamName: response.teamName,
    competitionId: response.competitionId,
    seasonId: response.seasonId,
    seasonName: response.seasonName,
    asOf: _requiredDateTime(response.asOf, 'as_of'),
    comparison: TeamProbabilityComparison(
      available: response.comparison.available,
      asOf: response.comparison.asOf == null
          ? null
          : _requiredDateTime(response.comparison.asOf!, 'comparison.as_of'),
    ),
    cards: [
      for (final card in response.cards)
        TeamProbabilityCard(
          event: card.event,
          competitionId: card.competitionId,
          category: card.category,
          probability: card.probability,
          changePercentagePoints: card.changePp,
          entropy: card.entropy,
        ),
    ],
    pendingOutcomes: response.pendingOutcomes,
  );
}

DateTime _requiredDateTime(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Expected valid date-time field "$field".');
  }
  return parsed.toUtc();
}
