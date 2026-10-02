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
    maximumPoints: response.maximumPoints,
    positions: [
      for (final item in response.positions)
        TeamPositionProbability(
          position: item.position,
          probability: item.probability,
        ),
    ],
    projectedPoints: TeamProjectedPoints(
      mean: response.projectedPoints.mean,
      likelyRange: TeamPointsInterval(
        lower: response.projectedPoints.likelyRange.lower,
        upper: response.projectedPoints.likelyRange.upper,
      ),
      changePoints: response.projectedPoints.changePoints,
    ),
    comparison: TeamProbabilityComparison(
      available: response.comparison.available,
      asOf: response.comparison.asOf == null
          ? null
          : _requiredDateTime(response.comparison.asOf!, 'comparison.as_of'),
    ),
    cards: [
      for (final card in response.cards) _cardFromResponse(card),
    ],
    history: [
      for (final point in response.history)
        TeamProbabilityHistoryPoint(
          asOf: _requiredDateTime(point.asOf, 'history.as_of'),
          played: point.played,
          events: point.events.map(_cardFromResponse).toList(growable: false),
          expectedPoints: point.expectedPoints,
        ),
    ],
    pendingOutcomes: response.pendingOutcomes,
    whatIf: _whatIfFromResponse(response.whatIf),
  );
}

TeamProbabilityWhatIf? _whatIfFromResponse(
  ApiTeamProbabilityWhatIfResponse? response,
) {
  if (response == null) return null;
  return TeamProbabilityWhatIf(
    fixture: TeamProbabilityWhatIfFixture(
      fixtureId: response.fixture.fixtureId,
      homeTeamId: response.fixture.homeTeamId,
      awayTeamId: response.fixture.awayTeamId,
      startingAt: _requiredDateTime(
        response.fixture.startingAt,
        'what_if.fixture.starting_at',
      ),
      roundName: response.fixture.roundName,
      probabilities: response.fixture.probabilities,
    ),
    scenarios: [
      for (final scenario in response.scenarios)
        TeamProbabilityWhatIfScenario(
          outcome: scenario.outcome,
          events:
              scenario.events.map(_cardFromResponse).toList(growable: false),
          positions: [
            for (final position in scenario.positions)
              TeamPositionProbability(
                position: position.position,
                probability: position.probability,
              ),
          ],
          projectedPoints: TeamProjectedPoints(
            mean: scenario.projectedPoints.mean,
            likelyRange: TeamPointsInterval(
              lower: scenario.projectedPoints.likelyRange.lower,
              upper: scenario.projectedPoints.likelyRange.upper,
            ),
            changePoints: scenario.projectedPoints.changePoints,
          ),
        ),
    ],
  );
}

TeamProbabilityCard _cardFromResponse(
  ApiTeamProbabilityCardResponse card,
) {
  return TeamProbabilityCard(
    event: card.event,
    competitionId: card.competitionId,
    category: card.category,
    probability: card.probability,
    changePercentagePoints: card.changePp,
    entropy: card.entropy,
    resolution: ProbabilityResolution.values.byName(card.resolution),
  );
}

DateTime _requiredDateTime(String value, String field) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('Expected valid date-time field "$field".');
  }
  return parsed.toUtc();
}
