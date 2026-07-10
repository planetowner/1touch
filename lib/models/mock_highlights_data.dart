import 'package:onetouch/models/team_highlight.dart';

// ═══════════════════════════════════════════════════════════
// TEAM HIGHLIGHTS  — YouTube highlight sources per Premier League team
// ═══════════════════════════════════════════════════════════

const mockHighlights = <TeamHighlight>[
  // West Ham United (team 1)
  TeamHighlight(teamId: 1, teamName: 'West Ham United', rankOrder: 1, title: 'Aston Villa 2-0 West Ham | Premier League Highlights', publishedAt: '2026-03-22 22:00:00', sourceType: 'channel_uploads', sourceRef: 'UUCNOsmurvpEit9paBOzWtUg'),
  // Sunderland (team 3)
  TeamHighlight(teamId: 3, teamName: 'Sunderland', rankOrder: 1, title: 'Extended Premier League Highlights | Newcastle United 1 - 2 Sunderland AFC', publishedAt: '2026-03-23 00:00:01', sourceType: 'playlist', sourceRef: 'PLuRgWp9ON5vr9yIJna4WeCeQSm4dTGhFl'),
  TeamHighlight(teamId: 3, teamName: 'Sunderland', rankOrder: 2, title: 'Brobbey Wins Derby In 90th Minute | Newcastle 1 - 2 Sunderland AFC | Premier League Highlights', publishedAt: '2026-03-22 22:00:28', sourceType: 'playlist', sourceRef: 'PLuRgWp9ON5vr9yIJna4WeCeQSm4dTGhFl'),
  TeamHighlight(teamId: 3, teamName: 'Sunderland', rankOrder: 3, title: 'Extended Premier League Highlights | Sunderland AFC 0 - 1 Brighton', publishedAt: '2026-03-15 00:00:31', sourceType: 'playlist', sourceRef: 'PLuRgWp9ON5vr9yIJna4WeCeQSm4dTGhFl'),
  // Tottenham Hotspur (team 6)
  TeamHighlight(teamId: 6, teamName: 'Tottenham Hotspur', rankOrder: 1, title: 'Spurs 0-3 Nottingham Forest | Premier League Highlights', publishedAt: '2026-03-22 22:00:05', sourceType: 'playlist', sourceRef: 'PLCQm3OPgov-if9jjzK-aoOLZ7C79b18k1'),
  TeamHighlight(teamId: 6, teamName: 'Tottenham Hotspur', rankOrder: 2, title: 'Richarlison SILENCES Anfield! | Liverpool 1-1 Spurs | Premier League Highlights', publishedAt: '2026-03-15 22:00:18', sourceType: 'playlist', sourceRef: 'PLCQm3OPgov-if9jjzK-aoOLZ7C79b18k1'),
  TeamHighlight(teamId: 6, teamName: 'Tottenham Hotspur', rankOrder: 3, title: 'Spurs 1-3 Crystal Palace l Premier League Highlights', publishedAt: '2026-03-06 00:00:48', sourceType: 'playlist', sourceRef: 'PLCQm3OPgov-if9jjzK-aoOLZ7C79b18k1'),
  // Liverpool (team 8)
  TeamHighlight(teamId: 8, teamName: 'Liverpool', rankOrder: 1, title: 'Highlights: Manchester City 4-0 Liverpool | FA Cup Quarter-Final', publishedAt: '2026-04-05 11:00:08', sourceType: 'playlist', sourceRef: 'PLR8DItC4f5xtq0Th2aa6KyiraLty-cSTG'),
  TeamHighlight(teamId: 8, teamName: 'Liverpool', rankOrder: 2, title: 'Highlights: Liverpool 4-0 Galatasaray | FOUR Goals as Reds Reach Champions League Quarter-Finals', publishedAt: '2026-03-19 23:00:58', sourceType: 'playlist', sourceRef: 'PLR8DItC4f5xtq0Th2aa6KyiraLty-cSTG'),
  TeamHighlight(teamId: 8, teamName: 'Liverpool', rankOrder: 3, title: 'Highlights: Liverpool 1-1 Spurs | Another Szoboszlai Free-Kick', publishedAt: '2026-03-15 22:00:03', sourceType: 'playlist', sourceRef: 'PLR8DItC4f5xtq0Th2aa6KyiraLty-cSTG'),
  // Manchester City (team 9)
  TeamHighlight(teamId: 9, teamName: 'Manchester City', rankOrder: 1, title: 'HIGHLIGHTS | Man City 4-0 Liverpool | Haaland hat-trick helps secure 8th FA Cup semi-final in a row!', publishedAt: '2026-04-05 11:00:38', sourceType: 'playlist', sourceRef: 'PLp_A7BZlpSOcsW23OdEvrC1KnhtrOpb0v'),
  TeamHighlight(teamId: 9, teamName: 'Manchester City', rankOrder: 2, title: 'HIGHLIGHTS! Man United 0-3 Man City | City edge closer to title with emphatic Manchester derby win!', publishedAt: '2026-03-28 19:20:00', sourceType: 'playlist', sourceRef: 'PLp_A7BZlpSOcsW23OdEvrC1KnhtrOpb0v'),
  TeamHighlight(teamId: 9, teamName: 'Manchester City', rankOrder: 3, title: 'HIGHLIGHTS | Carabao Cup Final 2026 | Arsenal 0-2 Man City | Dream O\'Reilly brace to win the cup!', publishedAt: '2026-03-23 00:00:01', sourceType: 'playlist', sourceRef: 'PLp_A7BZlpSOcsW23OdEvrC1KnhtrOpb0v'),
  // Fulham (team 11)
  TeamHighlight(teamId: 11, teamName: 'Fulham', rankOrder: 1, title: 'COMEBACK AT THE COTTAGE | JOSH, HARRY & RAUL STRIKE BACK | FULHAM 3-1 BURNLEY', publishedAt: '2026-03-21 22:00:06', sourceType: 'playlist', sourceRef: 'PLY8T1xH7hxoqgrkF1OIxjZpum7ylgr9g_'),
  TeamHighlight(teamId: 11, teamName: 'Fulham', rankOrder: 2, title: 'STALEMATE AT THE CITY GROUND | POINT ON THE ROAD | NOTTINGHAM FOREST 0-0 FULHAM', publishedAt: '2026-03-15 22:00:26', sourceType: 'playlist', sourceRef: 'PLY8T1xH7hxoqgrkF1OIxjZpum7ylgr9g_'),
  TeamHighlight(teamId: 11, teamName: 'Fulham', rankOrder: 3, title: 'Saints win with late penalty | FA CUP HIGHLIGHTS | Fulham 0-1 Southampton', publishedAt: '2026-03-09 12:01:46', sourceType: 'playlist', sourceRef: 'PLY8T1xH7hxoqgrkF1OIxjZpum7ylgr9g_'),
  // Everton (team 13)
  TeamHighlight(teamId: 13, teamName: 'Everton', rankOrder: 1, title: 'EXTENDED Highlights: Everton 3-0 Chelsea', publishedAt: '2026-03-23 00:00:00', sourceType: 'playlist', sourceRef: 'PLkB7IpRClaTIq6_zXWIhIFd-5qfqrtPLk'),
  TeamHighlight(teamId: 13, teamName: 'Everton', rankOrder: 2, title: 'EVERTON 2-0 BURNLEY | Premier League highlights', publishedAt: '2026-03-03 23:30:06', sourceType: 'playlist', sourceRef: 'PLkB7IpRClaTIq6_zXWIhIFd-5qfqrtPLk'),
  TeamHighlight(teamId: 13, teamName: 'Everton', rankOrder: 3, title: 'NEWCASTLE 2-3 EVERTON | Premier League highlights', publishedAt: '2026-02-28 22:00:06', sourceType: 'playlist', sourceRef: 'PLkB7IpRClaTIq6_zXWIhIFd-5qfqrtPLk'),
  // Manchester United (team 14)
  TeamHighlight(teamId: 14, teamName: 'Manchester United', rankOrder: 1, title: 'A Point Away From Home | Bournemouth v Man Utd | Highlights', publishedAt: '2026-03-21 00:01:06', sourceType: 'playlist', sourceRef: 'PL5-QUghxmluLRUTCh-umhonToE-X_Dnu-'),
  TeamHighlight(teamId: 14, teamName: 'Manchester United', rankOrder: 2, title: 'Three MASSIVE Points! 🔥 | Man Utd v Aston Villa | Highlights', publishedAt: '2026-03-15 22:00:48', sourceType: 'playlist', sourceRef: 'PL5-QUghxmluLRUTCh-umhonToE-X_Dnu-'),
  TeamHighlight(teamId: 14, teamName: 'Manchester United', rankOrder: 3, title: 'Defeat Away From Home | Newcastle v Man Utd', publishedAt: '2026-03-05 00:00:01', sourceType: 'playlist', sourceRef: 'PL5-QUghxmluLRUTCh-umhonToE-X_Dnu-'),
  // Aston Villa (team 15)
  TeamHighlight(teamId: 15, teamName: 'Aston Villa', rankOrder: 1, title: 'Dominant Villa Park Performance 💥⚽ | HIGHLIGHTS | Aston Villa v West Ham United', publishedAt: '2026-03-22 22:00:17', sourceType: 'playlist', sourceRef: 'PLiR0-7AEE2Hotf1U_U7a2rO53BgZUjcNq'),
  TeamHighlight(teamId: 15, teamName: 'Aston Villa', rankOrder: 2, title: 'Into The Last Eight 🔥 | Aston Villa 2-0 Lille (3-0 AGG) | UEFA Europa League Highlights', publishedAt: '2026-03-20 23:00:25', sourceType: 'playlist', sourceRef: 'PLiR0-7AEE2Hotf1U_U7a2rO53BgZUjcNq'),
  TeamHighlight(teamId: 15, teamName: 'Aston Villa', rankOrder: 3, title: 'Manchester United 3-1 Aston Villa | Premier League Highlights', publishedAt: '2026-03-15 22:00:43', sourceType: 'playlist', sourceRef: 'PLiR0-7AEE2Hotf1U_U7a2rO53BgZUjcNq'),
  // Chelsea (team 18)
  TeamHighlight(teamId: 18, teamName: 'Chelsea', rankOrder: 1, title: 'Chelsea 7-0 Port Vale | HIGHLIGHTS | FA Cup 2025/26', publishedAt: '2026-04-05 11:00:45', sourceType: 'playlist', sourceRef: 'PLx6bGx4zt6EkvHD82pE-_TyduEY79ZQ_q'),
  TeamHighlight(teamId: 18, teamName: 'Chelsea', rankOrder: 2, title: 'Everton 3-0 Chelsea | HIGHLIGHTS | Premier League 2025/26', publishedAt: '2026-03-21 22:00:40', sourceType: 'playlist', sourceRef: 'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1'),
  TeamHighlight(teamId: 18, teamName: 'Chelsea', rankOrder: 3, title: 'Chelsea 0-1 Newcastle | HIGHLIGHTS | Premier League 2025/26', publishedAt: '2026-03-14 22:00:42', sourceType: 'playlist', sourceRef: 'PLx6bGx4zt6Emu0lOP9KsAknui6vKHXVC1'),
  // Arsenal (team 19)
  TeamHighlight(teamId: 19, teamName: 'Arsenal', rankOrder: 1, title: 'HIGHLIGHTS | Arsenal vs Manchester City (0-2) | Carabao Cup Final', publishedAt: '2026-03-23 00:01:08', sourceType: 'playlist', sourceRef: 'PLvuwbYTkUzHcWbmTUwc_TDprJHvpOZQCV'),
  TeamHighlight(teamId: 19, teamName: 'Arsenal', rankOrder: 2, title: 'EZE & RICE WONDERGOALS! | Arsenal vs Bayer Leverkusen (2-0, 3-1 on agg) | UCL Highlights |', publishedAt: '2026-03-18 00:00:41', sourceType: 'playlist', sourceRef: 'PLvuwbYTkUzHcWbmTUwc_TDprJHvpOZQCV'),
  TeamHighlight(teamId: 19, teamName: 'Arsenal', rankOrder: 3, title: 'DOWMAN MAKES HISTORY | EXTENDED HIGHLIGHTS | Arsenal vs Everton (2-0) | Gyokeres, Dowman | PL', publishedAt: '2026-03-16 00:00:35', sourceType: 'playlist', sourceRef: 'PLvuwbYTkUzHcWbmTUwc_TDprJHvpOZQCV'),
  // Newcastle United (team 20)
  TeamHighlight(teamId: 20, teamName: 'Newcastle United', rankOrder: 1, title: 'Chelsea 0 Newcastle United 1 | Premier League Highlights', publishedAt: '2026-03-14 22:00:32', sourceType: 'playlist', sourceRef: 'PLb39HY4ZwBVkhGGO_Yxn3KsUeiEmUthE2'),
  TeamHighlight(teamId: 20, teamName: 'Newcastle United', rankOrder: 2, title: 'Newcastle United 1 Barcelona 1 | UEFA Champions League Highlights', publishedAt: '2026-03-13 09:42:29', sourceType: 'playlist', sourceRef: 'PLb39HY4ZwBVkhGGO_Yxn3KsUeiEmUthE2'),
  TeamHighlight(teamId: 20, teamName: 'Newcastle United', rankOrder: 3, title: 'WILL OSULA LATE WINNER 🤩 Newcastle United 2 Manchester United 1 | Premier League Highlights', publishedAt: '2026-03-05 00:00:35', sourceType: 'playlist', sourceRef: 'PLb39HY4ZwBVkhGGO_Yxn3KsUeiEmUthE2'),
  // Burnley (team 27)
  TeamHighlight(teamId: 27, teamName: 'Burnley', rankOrder: 1, title: 'Fulham v Burnley | Premier League Highlights', publishedAt: '2026-03-21 22:00:06', sourceType: 'playlist', sourceRef: 'PLT0NSkVOxxL-iyqnA1hXAR_xz3hq4ko2u'),
  TeamHighlight(teamId: 27, teamName: 'Burnley', rankOrder: 2, title: 'Extended Premier League Highlights | Burnley v AFC Bournemouth', publishedAt: '2026-03-15 00:00:06', sourceType: 'playlist', sourceRef: 'PLT0NSkVOxxL-iyqnA1hXAR_xz3hq4ko2u'),
  TeamHighlight(teamId: 27, teamName: 'Burnley', rankOrder: 3, title: 'Burnley v AFC Bournemouth | Premier League Highlights', publishedAt: '2026-03-14 22:00:06', sourceType: 'playlist', sourceRef: 'PLT0NSkVOxxL-iyqnA1hXAR_xz3hq4ko2u'),
  // Wolverhampton Wanderers (team 29)
  TeamHighlight(teamId: 29, teamName: 'Wolverhampton Wanderers', rankOrder: 1, title: 'Armstrong and Arokodare net in draw! | Brentford 2-2 Wolves | Extended Highlights', publishedAt: '2026-03-18 00:00:38', sourceType: 'channel_uploads', sourceRef: 'UUQ7Lqg5Czh5djGK6iOG53KQ'),
  TeamHighlight(teamId: 29, teamName: 'Wolverhampton Wanderers', rankOrder: 2, title: 'Defeat in the FA Cup | Wolves 1-3 Liverpool | Extended Highlights', publishedAt: '2026-03-07 12:01:33', sourceType: 'channel_uploads', sourceRef: 'UUQ7Lqg5Czh5djGK6iOG53KQ'),
  TeamHighlight(teamId: 29, teamName: 'Wolverhampton Wanderers', rankOrder: 3, title: 'Back-to-back wins! | Wolves 2-1 Liverpool | Extended Highlights', publishedAt: '2026-03-05 00:00:01', sourceType: 'channel_uploads', sourceRef: 'UUQ7Lqg5Czh5djGK6iOG53KQ'),
  // Crystal Palace (team 51)
  TeamHighlight(teamId: 51, teamName: 'Crystal Palace', rankOrder: 1, title: 'Match Highlights | AEK Larnaca 1-2 Crystal Palace | UEFA Conference League', publishedAt: '2026-03-21 00:00:24', sourceType: 'channel_uploads', sourceRef: 'UUWB9N0012fG6bGyj486Qxmg'),
  TeamHighlight(teamId: 51, teamName: 'Crystal Palace', rankOrder: 2, title: 'FIRST HALF DRAMA 🚨 | Crystal Palace 0-0 Leeds United | Premier League Highlights', publishedAt: '2026-03-15 20:00:35', sourceType: 'channel_uploads', sourceRef: 'UUWB9N0012fG6bGyj486Qxmg'),
  TeamHighlight(teamId: 51, teamName: 'Crystal Palace', rankOrder: 3, title: 'Match Highlights | Crystal Palace 0-0 AEK Larnaca | UEFA Conference League', publishedAt: '2026-03-14 00:00:39', sourceType: 'channel_uploads', sourceRef: 'UUWB9N0012fG6bGyj486Qxmg'),
  // AFC Bournemouth (team 52)
  TeamHighlight(teamId: 52, teamName: 'AFC Bournemouth', rankOrder: 1, title: 'Tavernier strikes the woodwork twice in Bees stalemate | AFC Bournemouth 0-0 Brentford', publishedAt: '2026-03-03 23:00:28', sourceType: 'playlist', sourceRef: 'PLDSAlkBZMWj5N7tdhX2uI5YkLFnD3V7VI'),
  TeamHighlight(teamId: 52, teamName: 'AFC Bournemouth', rankOrder: 2, title: 'Rayan and Adli instrumental in HUGE second half turnaround | Everton 1-2 AFC Bournemouth', publishedAt: '2026-02-10 22:59:38', sourceType: 'playlist', sourceRef: 'PLDSAlkBZMWj5N7tdhX2uI5YkLFnD3V7VI'),
  TeamHighlight(teamId: 52, teamName: 'AFC Bournemouth', rankOrder: 3, title: 'Rayan scores first Premier League goal on his full debut | AFC Bournemouth 1-1 Aston Villa', publishedAt: '2026-02-07 18:44:18', sourceType: 'playlist', sourceRef: 'PLDSAlkBZMWj5N7tdhX2uI5YkLFnD3V7VI'),
  // Nottingham Forest (team 63)
  TeamHighlight(teamId: 63, teamName: 'Nottingham Forest', rankOrder: 1, title: 'BIG THREE POINTS! 🔥 | Nottingham Forest 3-1 Leeds United | Premier League Highlights', publishedAt: '2025-11-09 22:00:45', sourceType: 'playlist', sourceRef: 'PLooQvgG3c7czcVlEp3f-wfZL-n2mTgyLS'),
  TeamHighlight(teamId: 63, teamName: 'Nottingham Forest', rankOrder: 2, title: 'Sturm Graz 0-0 Nottingham Forest | UEFA Europa League | Highlights', publishedAt: '2025-11-07 23:00:40', sourceType: 'playlist', sourceRef: 'PLooQvgG3c7czcVlEp3f-wfZL-n2mTgyLS'),
  TeamHighlight(teamId: 63, teamName: 'Nottingham Forest', rankOrder: 3, title: 'MGW & Savona On Target! 🎯 | Nottingham Forest 2-2 Manchester United | Premier League Highlights', publishedAt: '2025-11-01 22:00:02', sourceType: 'playlist', sourceRef: 'PLooQvgG3c7czcVlEp3f-wfZL-n2mTgyLS'),
  // Leeds United (team 71)
  TeamHighlight(teamId: 71, teamName: 'Leeds United', rankOrder: 1, title: 'Leeds United v Brentford | Premier League highlights', publishedAt: '2026-03-22 00:00:03', sourceType: 'channel_uploads', sourceRef: 'UUyQcJHDN4uYfPa1DHzKVSnw'),
  TeamHighlight(teamId: 71, teamName: 'Leeds United', rankOrder: 2, title: 'Red card drama | Crystal Palace 0-0 Leeds United | Premier League highlights', publishedAt: '2026-03-15 22:00:34', sourceType: 'channel_uploads', sourceRef: 'UUyQcJHDN4uYfPa1DHzKVSnw'),
  // Brighton & Hove Albion (team 78)
  TeamHighlight(teamId: 78, teamName: 'Brighton & Hove Albion', rankOrder: 1, title: 'EXTENDED HIGHLIGHTS | Brighton v Liverpool | Premier League', publishedAt: '2026-03-22 23:59:06', sourceType: 'playlist', sourceRef: 'PLU4NF13Grb9HXwr0ijDpE1G7gxdbRuOWO'),
  TeamHighlight(teamId: 78, teamName: 'Brighton & Hove Albion', rankOrder: 2, title: 'HIGHLIGHTS | Brighton v Liverpool | Premier League', publishedAt: '2026-03-21 22:00:39', sourceType: 'playlist', sourceRef: 'PLU4NF13Grb9HXwr0ijDpE1G7gxdbRuOWO'),
  TeamHighlight(teamId: 78, teamName: 'Brighton & Hove Albion', rankOrder: 3, title: 'EXTENDED HIGHLIGHTS | Sunderland v Brighton | Premier League', publishedAt: '2026-03-15 23:59:00', sourceType: 'playlist', sourceRef: 'PLU4NF13Grb9HXwr0ijDpE1G7gxdbRuOWO'),
  // Brentford (team 236)
  TeamHighlight(teamId: 236, teamName: 'Brentford', rankOrder: 1, title: 'Hard-fought point on the road 😤 | Leeds United 0-0 Brentford | Premier League Highlights', publishedAt: '2026-03-21 23:55:00', sourceType: 'playlist', sourceRef: 'PL62gtN0myLZYvjKuGPObM3sMeWml3FbQp'),
  TeamHighlight(teamId: 236, teamName: 'Brentford', rankOrder: 2, title: 'Kayode and Thiago on target 🎯 | Brentford 2-2 Wolverhampton Wanderers | Premier League Highlights', publishedAt: '2026-03-16 23:45:00', sourceType: 'playlist', sourceRef: 'PL62gtN0myLZYvjKuGPObM3sMeWml3FbQp'),
  TeamHighlight(teamId: 236, teamName: 'Brentford', rankOrder: 3, title: 'Bees exit the cup | West Ham 2-2 Brentford (5-3 pens) | Emirates FA Cup Highlights', publishedAt: '2026-03-11 14:14:04', sourceType: 'playlist', sourceRef: 'PL62gtN0myLZYvjKuGPObM3sMeWml3FbQp'),
];

List<TeamHighlight> highlightsByTeam(int teamId) => mockHighlights
    .where((h) => h.teamId == teamId)
    .toList()
  ..sort((a, b) => a.rankOrder.compareTo(b.rankOrder));
