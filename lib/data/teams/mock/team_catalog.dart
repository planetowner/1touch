import 'package:onetouch/data/competitions/mock/league_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/models/team.dart';

// ═══════════════════════════════════════════════════════════
// TEAMS  (teams table)
// ═══════════════════════════════════════════════════════════

const mockTeams = <Team>[
  // Premier League
  Team(
      teamId: 9,
      name: 'Manchester City',
      shortCode: 'MCI',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/9/9.png',
      primaryColor: 0xFF6CABDD),
  Team(
      teamId: 19,
      name: 'Arsenal',
      shortCode: 'ARS',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/19/19.png',
      primaryColor: 0xFFEF0107),
  Team(
      teamId: 8,
      name: 'Liverpool',
      shortCode: 'LIV',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/8/8.png',
      primaryColor: 0xFFC8102E),
  Team(
      teamId: 52,
      name: 'AFC Bournemouth',
      shortCode: 'BOU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/20/52.png',
      primaryColor: 0xFFDA291C),
  Team(
      teamId: 71,
      name: 'Leeds United',
      shortCode: 'LEE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/7/71.png',
      primaryColor: 0xFF1D428A),
  Team(
      teamId: 20,
      name: 'Newcastle United',
      shortCode: 'NEW',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/20/20.png',
      primaryColor: 0xFF241F20),
  Team(
      teamId: 236,
      name: 'Brentford',
      shortCode: 'BRE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/12/236.png',
      primaryColor: 0xFFE30613),
  Team(
      teamId: 51,
      name: 'Crystal Palace',
      shortCode: 'CRY',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/19/51.png',
      primaryColor: 0xFF1B458F),
  Team(
      teamId: 78,
      name: 'Brighton & Hove Albion',
      shortCode: 'BHA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/78.png',
      primaryColor: 0xFF0057B8),
  Team(
      teamId: 14,
      name: 'Manchester United',
      shortCode: 'MUN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/14.png',
      primaryColor: 0xFFDA291C),
  Team(
      teamId: 18,
      name: 'Chelsea',
      shortCode: 'CHE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/18/18.png',
      primaryColor: 0xFF034694),
  Team(
      teamId: 15,
      name: 'Aston Villa',
      shortCode: 'AVL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/15/15.png',
      primaryColor: 0xFF670E36),
  Team(
      teamId: 6,
      name: 'Tottenham Hotspur',
      shortCode: 'TOT',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/6/6.png',
      primaryColor: 0xFF132257),
  Team(
      teamId: 13,
      name: 'Everton',
      shortCode: 'EVE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/13/13.png',
      primaryColor: 0xFF003399),
  Team(
      teamId: 3,
      name: 'Sunderland',
      shortCode: 'SUN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/3/3.png',
      primaryColor: 0xFFEB172B),
  Team(
      teamId: 11,
      name: 'Fulham',
      shortCode: 'FUL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/11/11.png',
      primaryColor: 0xFF1B1B1B),
  Team(
      teamId: 1,
      name: 'West Ham United',
      shortCode: 'WHU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/1/1.png',
      primaryColor: 0xFF7A263A),
  Team(
      teamId: 63,
      name: 'Nottingham Forest',
      shortCode: 'NFO',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/31/63.png',
      primaryColor: 0xFFDD0000),
  Team(
      teamId: 29,
      name: 'Wolverhampton Wanderers',
      shortCode: 'WOL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/29/29.png',
      primaryColor: 0xFFFDB913),
  Team(
      teamId: 27,
      name: 'Burnley',
      shortCode: 'BUR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/27/27.png',
      primaryColor: 0xFF6C1D45),
  // La Liga
  Team(
      teamId: 83,
      name: 'FC Barcelona',
      shortCode: 'BAR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/19/83.png',
      primaryColor: 0xFFA50044),
  Team(
      teamId: 3468,
      name: 'Real Madrid',
      shortCode: 'RMA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/12/3468.png',
      primaryColor: 0xFFFEBE10),
  Team(
      teamId: 3477,
      name: 'Villarreal',
      shortCode: 'VIL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/21/3477.png',
      primaryColor: 0xFFFFCF00),
  Team(
      teamId: 485,
      name: 'Real Betis',
      shortCode: 'BET',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/5/485.png',
      primaryColor: 0xFF00954C),
  Team(
      teamId: 7980,
      name: 'Atlético Madrid',
      shortCode: 'ATM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/12/7980.png',
      primaryColor: 0xFFCB3524),
  Team(
      teamId: 594,
      name: 'Real Sociedad',
      shortCode: 'RSO',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/18/594.png',
      primaryColor: 0xFF0067B1),
  Team(
      teamId: 13258,
      name: 'Athletic Club',
      shortCode: 'ATH',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/10/13258.png',
      primaryColor: 0xFFEE2523),
  Team(
      teamId: 377,
      name: 'Rayo Vallecano',
      shortCode: 'RAY',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/25/377.png',
      primaryColor: 0xFFE30613),
  Team(
      teamId: 459,
      name: 'Osasuna',
      shortCode: 'OSA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/11/459.png',
      primaryColor: 0xFF0A346F),
  Team(
      teamId: 36,
      name: 'Celta de Vigo',
      shortCode: 'CEL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/4/36.png',
      primaryColor: 0xFF63B0E3),
  Team(
      teamId: 214,
      name: 'Valencia',
      shortCode: 'VAL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/22/214.png',
      primaryColor: 0xFFF18E00),
  Team(
      teamId: 2975,
      name: 'Deportivo Alavés',
      shortCode: 'ALA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/31/2975.png',
      primaryColor: 0xFF0761AF),
  Team(
      teamId: 106,
      name: 'Getafe',
      shortCode: 'GET',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/10/106.png',
      primaryColor: 0xFF005999),
  Team(
      teamId: 231,
      name: 'Girona',
      shortCode: 'GIR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/7/231.png',
      primaryColor: 0xFFD3122A),
  Team(
      teamId: 3457,
      name: 'Levante',
      shortCode: 'LVT',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/1/3457.png',
      primaryColor: 0xFF004B9B),
  Team(
      teamId: 645,
      name: 'Mallorca',
      shortCode: 'MLL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/5/645.png',
      primaryColor: 0xFFCC0000),
  Team(
      teamId: 676,
      name: 'Sevilla',
      shortCode: 'SEV',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/4/676.png',
      primaryColor: 0xFFD9000D),
  Team(
      teamId: 528,
      name: 'Espanyol',
      shortCode: 'ESY',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/16/528.png',
      primaryColor: 0xFF0070B8),
  Team(
      teamId: 1099,
      name: 'Elche',
      shortCode: 'ELC',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/11/1099.png',
      primaryColor: 0xFF008000),
  Team(
      teamId: 93,
      name: 'Real Oviedo',
      shortCode: 'OVI',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/29/93.png',
      primaryColor: 0xFF004B9F),
  // Serie A
  Team(
      teamId: 2930,
      name: 'Inter',
      shortCode: 'INT',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/18/2930.png',
      primaryColor: 0xFF010E80),
  Team(
      teamId: 625,
      name: 'Juventus',
      shortCode: 'JUV',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/17/625.png',
      primaryColor: 0xFF1A1A1A),
  Team(
      teamId: 37,
      name: 'Roma',
      shortCode: 'ROM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/5/37.png',
      primaryColor: 0xFF8E1F2F),
  Team(
      teamId: 268,
      name: 'Como',
      shortCode: 'COM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/12/268.png',
      primaryColor: 0xFF004B9B),
  Team(
      teamId: 113,
      name: 'AC Milan',
      shortCode: 'MIL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/17/113.png',
      primaryColor: 0xFFCC0000),
  Team(
      teamId: 708,
      name: 'Atalanta',
      shortCode: 'ATA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/4/708.png',
      primaryColor: 0xFF1E71B8),
  Team(
      teamId: 597,
      name: 'Napoli',
      shortCode: 'NAP',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/21/597.png',
      primaryColor: 0xFF12A0D7),
  Team(
      teamId: 109,
      name: 'Fiorentina',
      shortCode: 'FIO',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/13/109.png',
      primaryColor: 0xFF592C82),
  Team(
      teamId: 2714,
      name: 'Sassuolo',
      shortCode: 'SAS',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/26/2714.png',
      primaryColor: 0xFF00A752),
  Team(
      teamId: 102,
      name: 'Genoa',
      shortCode: 'GEN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/6/102.png',
      primaryColor: 0xFFB01E23),
  Team(
      teamId: 8513,
      name: 'Bologna',
      shortCode: 'BOL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/1/8513.png',
      primaryColor: 0xFFA01E1F),
  Team(
      teamId: 43,
      name: 'Lazio',
      shortCode: 'LAZ',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/11/43.png',
      primaryColor: 0xFF3B7FBF),
  Team(
      teamId: 613,
      name: 'Torino',
      shortCode: 'TOR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/5/613.png',
      primaryColor: 0xFF7A1B1B),
  Team(
      teamId: 346,
      name: 'Udinese',
      shortCode: 'UDI',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/26/346.png',
      primaryColor: 0xFF1A1A1A),
  Team(
      teamId: 398,
      name: 'Parma',
      shortCode: 'PRM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/398.png',
      primaryColor: 0xFFFEDD00),
  Team(
      teamId: 1123,
      name: 'Hellas Verona',
      shortCode: 'VER',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/3/1123.png',
      primaryColor: 0xFF002E5B),
  Team(
      teamId: 10722,
      name: 'Cremonese',
      shortCode: 'USC',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/2/10722.png',
      primaryColor: 0xFF9E1B32),
  Team(
      teamId: 1072,
      name: 'Pisa',
      shortCode: 'PIS',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/16/1072.png',
      primaryColor: 0xFF00489B),
  Team(
      teamId: 585,
      name: 'Cagliari',
      shortCode: 'CAG',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/9/585.png',
      primaryColor: 0xFF9B1B30),
  Team(
      teamId: 7790,
      name: 'Lecce',
      shortCode: 'LEC',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/7790.png',
      primaryColor: 0xFFC8102E),
  // Bundesliga
  Team(
      teamId: 503,
      name: 'FC Bayern München',
      shortCode: 'FCB',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/23/503.png',
      primaryColor: 0xFFDC052D),
  Team(
      teamId: 68,
      name: 'Borussia Dortmund',
      shortCode: 'BVB',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/4/68.png',
      primaryColor: 0xFFFDE100),
  Team(
      teamId: 277,
      name: 'RB Leipzig',
      shortCode: 'RBL',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/21/277.png',
      primaryColor: 0xFFDD0741),
  Team(
      teamId: 3319,
      name: 'VfB Stuttgart',
      shortCode: 'VFB',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/23/3319.png',
      primaryColor: 0xFFE32219),
  Team(
      teamId: 2726,
      name: 'TSG Hoffenheim',
      shortCode: 'TSG',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/6/2726.png',
      primaryColor: 0xFF1C63B7),
  Team(
      teamId: 3321,
      name: 'Bayer 04 Leverkusen',
      shortCode: 'B04',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/25/3321.png',
      primaryColor: 0xFFE32221),
  Team(
      teamId: 3543,
      name: 'SC Freiburg',
      shortCode: 'SCF',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/23/3543.png',
      primaryColor: 0xFFE2001A),
  Team(
      teamId: 794,
      name: 'FSV Mainz 05',
      shortCode: 'M05',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/26/794.png',
      primaryColor: 0xFFED1C24),
  Team(
      teamId: 366,
      name: 'Eintracht Frankfurt',
      shortCode: 'SGE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/366.png',
      primaryColor: 0xFFE1000F),
  Team(
      teamId: 1079,
      name: 'FC Union Berlin',
      shortCode: 'FCU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/23/1079.png',
      primaryColor: 0xFFED1C24),
  Team(
      teamId: 90,
      name: 'FC Augsburg',
      shortCode: 'FCA',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/26/90.png',
      primaryColor: 0xFFBA3733),
  Team(
      teamId: 510,
      name: 'VfL Wolfsburg',
      shortCode: 'WOB',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/30/510.png',
      primaryColor: 0xFF65B32E),
  Team(
      teamId: 82,
      name: 'Werder Bremen',
      shortCode: 'SVW',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/18/82.png',
      primaryColor: 0xFF1D9053),
  Team(
      teamId: 3320,
      name: 'FC Köln',
      shortCode: 'KOE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/24/3320.png',
      primaryColor: 0xFFC8102E),
  Team(
      teamId: 683,
      name: 'Borussia Mönchengladbach',
      shortCode: 'BMG',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/11/683.png',
      primaryColor: 0xFF00954C),
  Team(
      teamId: 2708,
      name: 'Hamburger SV',
      shortCode: 'HSV',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/20/2708.png',
      primaryColor: 0xFF0A50A1),
  Team(
      teamId: 2831,
      name: 'Heidenheim',
      shortCode: 'HDH',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/15/2831.png',
      primaryColor: 0xFF005AA7),
  Team(
      teamId: 353,
      name: 'St. Pauli',
      shortCode: 'PAU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/1/353.png',
      primaryColor: 0xFF6C4A2E),
  // Ligue 1
  Team(
      teamId: 591,
      name: 'Paris Saint Germain',
      shortCode: 'PSG',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/15/591.png',
      primaryColor: 0xFF003087),
  Team(
      teamId: 44,
      name: 'Olympique Marseille',
      shortCode: 'OM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/12/44.png',
      primaryColor: 0xFF2FAEE0),
  Team(
      teamId: 271,
      name: 'Lens',
      shortCode: 'LEN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/15/271.png',
      primaryColor: 0xFFEA2127),
  Team(
      teamId: 690,
      name: 'LOSC Lille',
      shortCode: 'LOSC',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/18/690.png',
      primaryColor: 0xFFC8102E),
  Team(
      teamId: 6789,
      name: 'Monaco',
      shortCode: 'ASM',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/5/6789.png',
      primaryColor: 0xFFCE1126),
  Team(
      teamId: 79,
      name: 'Olympique Lyonnais',
      shortCode: 'LYO',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/15/79.png',
      primaryColor: 0xFF002B5C),
  Team(
      teamId: 686,
      name: 'Strasbourg',
      shortCode: 'STR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/14/686.png',
      primaryColor: 0xFF0090D4),
  Team(
      teamId: 598,
      name: 'Rennes',
      shortCode: 'REN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/22/598.png',
      primaryColor: 0xFFD30F26),
  Team(
      teamId: 289,
      name: 'Toulouse',
      shortCode: 'TOU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/1/289.png',
      primaryColor: 0xFF592C82),
  Team(
      teamId: 4508,
      name: 'Paris',
      shortCode: 'PFC',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/28/4508.png',
      primaryColor: 0xFF002D62),
  Team(
      teamId: 9257,
      name: 'Lorient',
      shortCode: 'LOR',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/9/9257.png',
      primaryColor: 0xFFED6A00),
  Team(
      teamId: 3682,
      name: 'Auxerre',
      shortCode: 'AUX',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/2/3682.png',
      primaryColor: 0xFF0060A9),
  Team(
      teamId: 1055,
      name: 'Le Havre',
      shortCode: 'LEH',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/31/1055.png',
      primaryColor: 0xFF00539F),
  Team(
      teamId: 266,
      name: 'Brest',
      shortCode: 'B29',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/10/266.png',
      primaryColor: 0xFFCC0000),
  Team(
      teamId: 450,
      name: 'Nice',
      shortCode: 'NCE',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/2/450.png',
      primaryColor: 0xFFC8102E),
  Team(
      teamId: 59,
      name: 'Nantes',
      shortCode: 'NAN',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/27/59.png',
      primaryColor: 0xFF009639),
  Team(
      teamId: 776,
      name: 'Angers SCO',
      shortCode: 'ANG',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/8/776.png',
      primaryColor: 0xFF1A1A1A),
  Team(
      teamId: 3513,
      name: 'Metz',
      shortCode: 'MTZ',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/25/3513.png',
      primaryColor: 0xFF7E1F3D),
  // Referenced by transfers (outside the Big 5 tables)
  Team(
      teamId: 21,
      name: 'Sheffield United',
      shortCode: 'SHU',
      imagePath: 'https://cdn.sportmonks.com/images/soccer/teams/21/21.png',
      primaryColor: 0xFFEE2737),
];

Team mockTeamById(int id) => mockTeams.firstWhere((t) => t.teamId == id);

// ═══════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════

// Returns "LEAGUE · Nth" for a team's primary domestic league standing.
String teamLeagueLabel(int teamId) {
  const domesticIds = {8, 82, 301, 384, 564};
  final s = mockStandings
      .where((s) => s.teamId == teamId && domesticIds.contains(s.leagueId))
      .firstOrNull;
  if (s == null) return '';
  final league = mockLeagueById(s.leagueId);
  final pos = s.position;
  final suffix = pos == 1
      ? '1st'
      : pos == 2
          ? '2nd'
          : pos == 3
              ? '3rd'
              : '${pos}th';
  return '${league.name} $suffix';
}
