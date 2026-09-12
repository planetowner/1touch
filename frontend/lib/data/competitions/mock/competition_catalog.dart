import 'package:onetouch/models/competition.dart';

const Map<int, String> competitionLabels = {
  8: 'Premier League',
  82: 'Bundesliga',
  301: 'Ligue 1',
  384: 'Serie A',
  564: 'La Liga',
  2: 'UEFA Champions League',
  5: 'UEFA Europa League',
  2286: 'UEFA Conference League',
  1371: 'UEFA Europa League Play-offs',
  24: 'FA Cup',
  27: 'Carabao Cup (EFL Cup)',
  390: 'Coppa Italia',
  570: 'Copa del Rey',
};

// Existing consumers use this subset to identify domestic Big Five leagues.
const Map<int, String> leagueNames = {
  8: 'Premier League',
  82: 'Bundesliga',
  301: 'Ligue 1',
  384: 'Serie A',
  564: 'La Liga',
};

// COMPETITIONS  (competitions table)

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
  // European competitions
  Competition(
      competitionId: 2,
      name: 'UEFA Champions League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/2/2.png'),
  Competition(
      competitionId: 5,
      name: 'UEFA Europa League',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/5/5.png'),
  Competition(
      competitionId: 2286,
      name: 'UEFA Conference League',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/2286/2286.png'),
  Competition(
      competitionId: 1371,
      name: 'UEFA Europa League Play-offs',
      imagePath:
          'https://cdn.sportmonks.com/images/soccer/leagues/1371/1371.png'),
  //   Domestic cups                      
  Competition(
      competitionId: 24,
      name: 'FA Cup',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/leagues/24/24.png'),
  Competition(
      competitionId: 27,
      name: 'Carabao Cup (EFL Cup)',
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
  // Legacy mock-only competitions retained because fixture data references
  // them even though they are outside the supported competition label map.
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

// 
