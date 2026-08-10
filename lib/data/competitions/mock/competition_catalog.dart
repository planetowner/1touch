import 'package:onetouch/models/competition.dart';

const Map<int, String> leagueNames = {
  8: 'Premier League',
  564: 'La Liga',
  82: 'Bundesliga',
  384: 'Serie A',
  301: 'Ligue 1',
};

// COMPETITIONS  (competitions table)
// ═══════════════════════════════════════════════════════════

const mockCompetitions = <Competition>[
  // Big 5 domestic leagues
  Competition(
      competitionId: 8,
      name: 'Premier League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/8/8.png'),
  Competition(
      competitionId: 564,
      name: 'La Liga',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/564/564.png'),
  Competition(
      competitionId: 82,
      name: 'Bundesliga',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/82/82.png'),
  Competition(
      competitionId: 384,
      name: 'Serie A',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/384/384.png'),
  Competition(
      competitionId: 301,
      name: 'Ligue 1',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/301/301.png'),
  // ── European competitions ─────────────────────────────────
  Competition(
      competitionId: 2,
      name: 'UCL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/2/2.png'),
  Competition(
      competitionId: 5,
      name: 'Europa League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/5/5.png'),
  // ── Domestic cups ─────────────────────────────────────────
  Competition(
      competitionId: 24,
      name: 'FA Cup',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/24/24.png'),
  Competition(
      competitionId: 27,
      name: 'EFL Cup',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/27/27.png'),
  Competition(
      competitionId: 570,
      name: 'Copa del Rey',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/570/570.png'),
  Competition(
      competitionId: 390,
      name: 'Coppa Italia',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/390/390.png'),
  Competition(
      competitionId: 392,
      name: 'DFB Pokal',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/392/392.png'),
  Competition(
      competitionId: 569,
      name: 'Coupe de France',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/569/569.png'),
];

Competition mockCompetitionById(int id) => mockCompetitions.firstWhere(
      (competition) => competition.competitionId == id,
      orElse: () => Competition(competitionId: id, name: 'Unknown'),
    );

// ═══════════════════════════════════════════════════════════
