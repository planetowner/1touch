import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import "package:onetouch/core/stylesheet_dark.dart";
// import 'package:onetouch/data/teamdata.dart';
import 'package:onetouch/data/matchdata.dart';

// =============================================================================
// UTILITIES & HELPERS
// =============================================================================

String ordinal(int number) {
  if (number >= 11 && number <= 13) return '${number}th';
  switch (number % 10) {
    case 1:
      return '${number}st';
    case 2:
      return '${number}nd';
    case 3:
      return '${number}rd';
    default:
      return '${number}th';
  }
}

String _formatDate(String isoDate) {
  final dt = DateTime.parse(isoDate).toLocal();
  return DateFormat('EEE, MMM d h:mm a').format(dt);
}

String determineMatchStatus(DateTime matchDateTime) {
  final now = DateTime.now();
  final matchEndTime = matchDateTime.add(const Duration(hours: 2));

  if (now.isAfter(matchEndTime)) {
    return 'past';
  } else if (now.isAfter(matchDateTime) && now.isBefore(matchEndTime)) {
    return 'live';
  } else {
    return 'upcoming';
  }
}

// =============================================================================
// MAIN WIDGETS (MatchCards)
// =============================================================================

class MatchCard extends StatelessWidget {
  final MatchData? match;
  final String? leagueName;

  const MatchCard({
    super.key,
    required this.match,
    this.leagueName,
  });

  @override
  Widget build(BuildContext context) {
    final home = match?.homeTeam;
    final away = match?.awayTeam;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Color(0xFF3D3D3D)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('NEXT MATCH', style: Body1_b.style),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _TeamDisplay(
                  teamName: home?.name ?? 'Home',
                  teamLogo: home?.imagePath ?? '',
                ),
              ),
              const SizedBox(width: 24),
              _MatchInfo(match: match, leagueName: leagueName),
              const SizedBox(width: 24),
              Expanded(
                child: _TeamDisplay(
                  teamName: away?.name ?? 'Away',
                  teamLogo: away?.imagePath ?? '',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MatchCard2 extends StatelessWidget {
  final String date,
      venue,
      team1shortname,
      team1Logo,
      team2shortname,
      team2Logo;

  const MatchCard2({
    super.key,
    required this.date,
    required this.venue,
    required this.team1shortname,
    required this.team1Logo,
    required this.team2shortname,
    required this.team2Logo,
  });

  @override
  Widget build(BuildContext context) {
    // Example scores
    const score1 = 3;
    const score2 = 2;

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      decoration: const BoxDecoration(color: Color(0x00B40000)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            SizedBox(width: 8),
            Text('LAST MATCH', style: Body1_b.style),
          ]),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: _TeamDisplay2(
                      teamName: team1shortname,
                      teamLogo: team1Logo,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ScoreBoard(score: score1, isDimmed: score1 < score2),
                  const SizedBox(width: 16),
                  _MatchInfo2(date: date, venue: venue),
                  const SizedBox(width: 16),
                  const _ScoreBoard(score: score2, isDimmed: score2 < score1),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TeamDisplay2(
                      teamName: team2shortname,
                      teamLogo: team2Logo,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// class MatchCard3 extends StatelessWidget {
//   final String date, venue, team1Name, team1Logo, team2Name, team2Logo;
//
//   const MatchCard3({
//     super.key,
//     required this.date,
//     required this.venue,
//     required this.team1Name,
//     required this.team1Logo,
//     required this.team2Name,
//     required this.team2Logo,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: const BoxDecoration(
//         borderRadius: BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//           bottomLeft: Radius.circular(0),
//           bottomRight: Radius.circular(0),
//         ),
//         color: Color(0xFF3D3D3D),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text('NEXT MATCH', style: Body1_b.style),
//           const SizedBox(height: 16),
//           LayoutBuilder(
//             builder: (context, constraints) {
//               return Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Expanded(
//                     child: _TeamDisplay(teamName: team1Name, teamLogo: team1Logo),
//                   ),
//                   const SizedBox(width: 24),
//                   _MatchInfo(match: , leagueName: ,), // Commented out in original
//                   const SizedBox(width: 24),
//                   Expanded(
//                     child: _TeamDisplay(teamName: team2Name, teamLogo: team2Logo),
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//       ),
//     );
//   }
// }

class SearchMatchCard extends StatelessWidget {
  final String homeTeam;
  final String homeLogo;
  final String awayTeam;
  final String awayLogo;
  final String date;
  final String time;

  const SearchMatchCard({
    super.key,
    required this.homeTeam,
    required this.homeLogo,
    required this.awayTeam,
    required this.awayLogo,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {

    const score1 = 3;
    const score2 = 2;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark card bg
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // HOME TEAM (Left)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 45,
                  height: 45,
                  child: Image.asset(
                    homeLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) =>
                    const Icon(Icons.shield, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  homeTeam,
                  style: Body2.style.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // CENTER INFO (# Date/Time #)
          Row(
            children: [
              // Reusing the internal _ScoreBoard with "#"
              const _ScoreBoard(score: score1, isDimmed: false),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const _ScoreBoard(score: score2, isDimmed: true),
            ],
          ),

          // AWAY TEAM (Right)
          Expanded(
            child: Column(
              children: [
                SizedBox(
                  width: 45,
                  height: 45,
                  child: Image.asset(
                    awayLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) =>
                    const Icon(Icons.shield, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  awayTeam,
                  style: Body2.style.copyWith(color: Colors.white),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INTERNAL WIDGET COMPONENTS
// =============================================================================

class _TeamDisplay extends StatelessWidget {
  final String teamName, teamLogo;
  const _TeamDisplay({required this.teamName, required this.teamLogo});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (teamLogo.isNotEmpty)
          Image.network(
            teamLogo,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
            const Icon(Icons.sports_soccer, color: Colors.white),
          ),
        const SizedBox(height: 8),
        Text(teamName, textAlign: TextAlign.center, style: Eyebrow.style),
      ],
    );
  }
}

class _TeamDisplay2 extends StatelessWidget {
  final String teamName, teamLogo;
  const _TeamDisplay2({required this.teamName, required this.teamLogo});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
            teamLogo, width: 48, height: 48, fit: BoxFit.cover
        ),
        const SizedBox(height: 8),
        Text(teamName, textAlign: TextAlign.center, style: Eyebrow.style),
      ],
    );
  }
}

class _MatchInfo extends StatelessWidget {
  final MatchData? match;
  final String? leagueName;
  const _MatchInfo({required this.match, this.leagueName});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 96,
          child: Text(
            _formatDate(match!.date),
            textAlign: TextAlign.center,
            style: Body2.style,
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 24, height: 1, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 8),
        Text(
          '${leagueName ?? 'League'}  ${match?.roundId}',
          style: Body2.style,
        ),
        const SizedBox(height: 4),
        // Text('Venue ID ${match?.venueId}', style: .style),
      ],
    );
  }
}

class _MatchInfo2 extends StatelessWidget {
  final String date, venue;
  const _MatchInfo2({required this.date, required this.venue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          child: Text(date, textAlign: TextAlign.center, style: Body2.style),
        ),
      ],
    );
  }
}

class _ScoreBoard extends StatelessWidget {
  final int score;
  final bool isDimmed;

  const _ScoreBoard({
    required this.score,
    required this.isDimmed,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDimmed ? 0.5 : 1.0,
      child: Material(
        elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            score.toString(),
            textAlign: TextAlign.center,
            style: Heading3.style,
          ),
        ),
      ),
    );
  }
}