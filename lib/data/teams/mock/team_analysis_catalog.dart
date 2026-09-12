import 'package:onetouch/models/team_attribute_scores.dart';

// TEAM ATTRIBUTE SCORES — for the radar chart on Analysis tab
//
//
// Proposed six-axis product mapping (Big 5 only):
//   attack       ← finishing.display_score_0_100
//   progression  ← attacking_threat.display_score_0_100
//   dominance    ← chance_creation.display_score_0_100
//   defense      ← defending.display_score_0_100
//   possession   ← possession_build_up.display_score_0_100
//   pressure     ← proposed composite from raw feature:
//                  clamp(50 + 15 * z(-dangerous_attacks_against_per_match), 5, 95)
//                  i.e. lower dangerous_attacks_against = higher pressure score.
//                  This is conceptually distinct from `defending`, which is
//                  about resisting shots/goals once they occur. Pressure
//                  measures preventing the opponent from creating chances
//                  in the first place.
//
// Display range: 5-95 (per loader's clamp).
// seasonLabel is denormalized here for picker convenience; real API would
// join with the seasons table.
//
// These scores are illustrative. The backend currently exposes five attribute
// groups and includes dangerous_attacks_against_per_match under defending; it
// does not yet expose an independent pressure score. Replace this catalog only
// after the backend defines and tests the required six-axis API contract.

const mockTeamAttributes = <TeamAttributeScores>[
  //   FC Barcelona
  TeamAttributeScores(
      teamId: 83,
      seasonId: 23621,
      seasonLabel: '24/25',
      attack: 92,
      progression: 85,
      pressure: 78,
      dominance: 88,
      defense: 75,
      possession: 94),
  TeamAttributeScores(
      teamId: 83,
      seasonId: 19799,
      seasonLabel: '22/23',
      attack: 82,
      progression: 78,
      pressure: 70,
      dominance: 80,
      defense: 82,
      possession: 89),
  TeamAttributeScores(
      teamId: 83,
      seasonId: 18462,
      seasonLabel: '21/22',
      attack: 75,
      progression: 72,
      pressure: 65,
      dominance: 75,
      defense: 78,
      possession: 86),
  TeamAttributeScores(
      teamId: 83,
      seasonId: 17480,
      seasonLabel: '20/21',
      attack: 72,
      progression: 70,
      pressure: 62,
      dominance: 73,
      defense: 75,
      possession: 88),

  //   Real Madrid
  TeamAttributeScores(
      teamId: 3468,
      seasonId: 23621,
      seasonLabel: '24/25',
      attack: 88,
      progression: 82,
      pressure: 75,
      dominance: 84,
      defense: 82,
      possession: 80),
  TeamAttributeScores(
      teamId: 3468,
      seasonId: 19799,
      seasonLabel: '22/23',
      attack: 85,
      progression: 80,
      pressure: 73,
      dominance: 82,
      defense: 85,
      possession: 78),
  TeamAttributeScores(
      teamId: 3468,
      seasonId: 18462,
      seasonLabel: '21/22',
      attack: 90,
      progression: 78,
      pressure: 70,
      dominance: 85,
      defense: 80,
      possession: 75),

  //   Liverpool
  TeamAttributeScores(
      teamId: 8,
      seasonId: 23614,
      seasonLabel: '24/25',
      attack: 90,
      progression: 84,
      pressure: 80,
      dominance: 86,
      defense: 78,
      possession: 78),
  TeamAttributeScores(
      teamId: 8,
      seasonId: 19734,
      seasonLabel: '22/23',
      attack: 84,
      progression: 80,
      pressure: 82,
      dominance: 80,
      defense: 75,
      possession: 76),

  //   Arsenal
  TeamAttributeScores(
      teamId: 19,
      seasonId: 23614,
      seasonLabel: '24/25',
      attack: 87,
      progression: 85,
      pressure: 82,
      dominance: 83,
      defense: 85,
      possession: 81),
  TeamAttributeScores(
      teamId: 19,
      seasonId: 19734,
      seasonLabel: '22/23',
      attack: 80,
      progression: 78,
      pressure: 78,
      dominance: 78,
      defense: 80,
      possession: 76),

  //   Manchester City
  TeamAttributeScores(
      teamId: 9,
      seasonId: 23614,
      seasonLabel: '24/25',
      attack: 88,
      progression: 86,
      pressure: 84,
      dominance: 87,
      defense: 80,
      possession: 92),
  TeamAttributeScores(
      teamId: 9,
      seasonId: 19734,
      seasonLabel: '22/23',
      attack: 92,
      progression: 88,
      pressure: 86,
      dominance: 90,
      defense: 84,
      possession: 94),

  //   Bayern Munich
  TeamAttributeScores(
      teamId: 503,
      seasonId: 23744,
      seasonLabel: '24/25',
      attack: 90,
      progression: 84,
      pressure: 82,
      dominance: 85,
      defense: 78,
      possession: 86),

  //   PSG
  TeamAttributeScores(
      teamId: 591,
      seasonId: 23643,
      seasonLabel: '24/25',
      attack: 88,
      progression: 82,
      pressure: 75,
      dominance: 86,
      defense: 76,
      possession: 84),

  //   Inter Milan
  TeamAttributeScores(
      teamId: 2930,
      seasonId: 23746,
      seasonLabel: '24/25',
      attack: 86,
      progression: 80,
      pressure: 78,
      dominance: 82,
      defense: 84,
      possession: 80),
];

//
