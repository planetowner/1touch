import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import "package:onetouch/core/stylesheet_dark.dart";

class MatchCard extends StatelessWidget {
  final String date, venue, team1Name, team1Logo, team2Name, team2Logo;

  const MatchCard({
    super.key,
    required this.date,
    required this.venue,
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF3D3D3D)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT MATCH',
            style: Body1_b.style,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: _TeamDisplay(
                          teamName: team1Name, teamLogo: team1Logo)),
                  const SizedBox(width: 24),
                  _MatchInfo(date: date, venue: venue),
                  const SizedBox(width: 24),
                  Expanded(
                      child: _TeamDisplay(
                          teamName: team2Name, teamLogo: team2Logo)),
                ],
              );
            },
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
      decoration: BoxDecoration(color: const Color(0x00B40000)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SizedBox(width: 8),
            Text(
              'LAST MATCH',
              style: Body1_b.style,
            ),
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
                  _ScoreBoard(
                    score: score1,
                    isDimmed: score1 < score2,
                  ),
                  const SizedBox(width: 16),
                  _MatchInfo2(date: date, venue: venue),
                  const SizedBox(width: 16),
                  _ScoreBoard(
                    score: score2,
                    isDimmed: score2 < score1,
                  ),
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

class MatchCard3 extends StatelessWidget {
  final String date, venue, team1Name, team1Logo, team2Name, team2Logo;

  const MatchCard3({
    super.key,
    required this.date,
    required this.venue,
    required this.team1Name,
    required this.team1Logo,
    required this.team2Name,
    required this.team2Logo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20), // Rounded top-left
            topRight: Radius.circular(20), // Rounded top-right
            bottomLeft: Radius.circular(0), // No rounding
            bottomRight: Radius.circular(0), // No rounding
          ),
          color: const Color(0xFF3D3D3D)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEXT MATCH',
            style: Body1_b.style,
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                      child: _TeamDisplay(
                          teamName: team1Name, teamLogo: team1Logo)),
                  const SizedBox(width: 24),
                  _MatchInfo(date: date, venue: venue),
                  const SizedBox(width: 24),
                  Expanded(
                      child: _TeamDisplay(
                          teamName: team2Name, teamLogo: team2Logo)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeamDisplay extends StatelessWidget {
  final String teamName, teamLogo;

  const _TeamDisplay({required this.teamName, required this.teamLogo});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.network(teamLogo, width: 72, height: 72, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red),),
        const SizedBox(height: 8),
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: Eyebrow.style,
        ),
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
        SvgPicture.asset(teamLogo, width: 48, height: 48, fit: BoxFit.cover),
        const SizedBox(height: 8),
        Text(
          teamName,
          textAlign: TextAlign.center,
          style: Eyebrow.style,
        ),
      ],
    );
  }
}

class _MatchInfo extends StatelessWidget {
  final String date, venue;

  const _MatchInfo({required this.date, required this.venue});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            textAlign: TextAlign.center,
            date,
            style: Body2.style,
          ),
        ),
        const SizedBox(height: 8),
        Container(width: 24, height: 1, color: Colors.white.withOpacity(0.3)),
        const SizedBox(height: 8),
        Text(venue, style: Body2.style),
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
          child: Text(
            textAlign: TextAlign.center,
            date,
            style: Body2.style,
          ),
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
            color: Color(0xFF272828),
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
