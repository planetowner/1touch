import 'package:onetouch/models/league.dart';

const Map<int, String> leagueNames = {
  8: 'Premier League',
  564: 'La Liga',
  82: 'Bundesliga',
  384: 'Serie A',
  301: 'Ligue 1',
};

// LEAGUES  (leagues table)
// ═══════════════════════════════════════════════════════════

const mockLeagues = <League>[
  // Big 5 domestic leagues
  League(
      leagueId: 8,
      name: 'Premier League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/8/8.png'),
  League(
      leagueId: 564,
      name: 'La Liga',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/564/564.png'),
  League(
      leagueId: 82,
      name: 'Bundesliga',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/82/82.png'),
  League(
      leagueId: 384,
      name: 'Serie A',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/384/384.png'),
  League(
      leagueId: 301,
      name: 'Ligue 1',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/301/301.png'),
  // ── European competitions ─────────────────────────────────
  League(
      leagueId: 2,
      name: 'UCL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/2/2.png'),
  League(
      leagueId: 5,
      name: 'Europa League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/5/5.png'),
  // ── Domestic cups ─────────────────────────────────────────
  League(
      leagueId: 24,
      name: 'FA Cup',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/24/24.png'),
  League(
      leagueId: 27,
      name: 'EFL Cup',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/27/27.png'),
  League(
      leagueId: 570,
      name: 'Copa del Rey',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/570/570.png'),
  League(
      leagueId: 390,
      name: 'Coppa Italia',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/390/390.png'),
  League(
      leagueId: 392,
      name: 'DFB Pokal',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/392/392.png'),
  League(
      leagueId: 569,
      name: 'Coupe de France',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/569/569.png'),
];

League mockLeagueById(int id) => mockLeagues.firstWhere(
      (l) => l.leagueId == id,
      orElse: () => League(leagueId: id, name: 'Unknown'),
    );

// ═══════════════════════════════════════════════════════════
