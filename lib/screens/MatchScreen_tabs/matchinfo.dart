import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/matchdata.dart';

class MatchInfoTab extends StatelessWidget {
  final String matchId;
  final String matchStatus; // "past" or "live"

  MatchInfoTab({
    super.key,
    required this.matchId,
    required this.matchStatus,
  });

  bool get isLive => matchStatus == 'live';
  List<Substitute> subsTeamA = [
    Substitute(name: "Ferran Torres", minute: 82, goal: true, subIn: true),
    Substitute(name: "Raphinha"),
    Substitute(name: "Eric García"),
  ];

  List<Substitute> subsTeamB = [
    Substitute(name: "Tsygankov", minute: 82, subIn: true, goal: true),
    Substitute(name: "Dovbyk"),
    Substitute(name: "Blind"),
  ];

  String coachA = "Xavi";
  String coachB = "Michel";

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric( vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildScoreHeader(),
          const SizedBox(height: 12,),
          _buildMatchEvents(),
          if (!isLive)...[
            const SizedBox(height: 24),
            _buildHighlights(),
          ],
          if (!isLive) ...[
            const SizedBox(height: 32),
            _buildPlayerOfTheMatch(),
          ],
          const SizedBox(height: 48),
          _buildMomentumChart(),
          const SizedBox(height: 48),
          _buildStatBars(),
          const SizedBox(height: 48),
          _buildLineup(),
          const SizedBox(height: 48),
          _buildSubstitutesAndCoach(
            subsA: subsTeamA,
            subsB: subsTeamB,
            coachA: coachA,
            coachB: coachB,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _teamBlock("TeamLogos/Barcelona.png", "Team Name"),
        const SizedBox(width: 20,),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272828),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('#', style: Heading1.style),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272828),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('#', style: Heading1.style),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(isLive ? "42:02" : "Final", style: Body2_b.style),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.30,
              child: Container(
                width: 24,
                height: 1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text("Venue Name", style: Body2.style),
          ],
        ),
        const SizedBox(width: 20,),
        _teamBlock("TeamLogos/Girona.png", "Team Name"),
      ],
    );
  }

  Widget _teamBlock(String logo, String name) {
    return Column(
      children: [
        Image.asset(logo, width: 72, height: 72),
        const SizedBox(height: 8),
        Text(name, style: Body1.style),
      ],
    );
  }

  Widget _buildMatchEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eventRowLeft("Player Name", "##’"),
          const SizedBox(height: 16),
          _eventRowRight("##’", "Player Name"),
          const SizedBox(height: 16),
          _eventRowRight("##’", "Player Name"),
        ],
      ),
    );
  }

  Widget _eventRowLeft(String player, String minute) {
    return Row(
      children: [
        const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
        const SizedBox(width: 6),
        Text(player, style: Body1.style),
        const Spacer(),
        Text(minute, style: Body1.style),
      ],
    );
  }

  Widget _eventRowRight(String minute, String player) {
    return Row(
      children: [
        Text(minute, style: Body1.style),
        const Spacer(),
        Text(player, style: Body1.style),
        const SizedBox(width: 6),
        const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
      ],
    );
  }

  Widget _buildHighlights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HIGHLIGHTS", style: Body2_b.style),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            'assets/highlight1.png',
            width: double.infinity,
            height: 194,
            fit: BoxFit.cover,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerOfTheMatch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PLAYER OF THE MATCH", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xCC272929),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("8.9", style: Heading2.style),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 42,),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    "Player\nName",
                    style: Heading5.style,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8,),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Team Name • ##',
                    style: Body2.style,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildMomentumChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("MOMENTUM", style: Body2_b.style),
        SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: Placeholder(), // Replace with real chart or live chart stream
        ),
      ],
    );
  }

  Widget _buildStatBars() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildStatComparisonBar(
          category: "Possession",
          homePercent: 64,
          awayPercent: 36,
        ),
        buildStatComparisonBar(
          category: "Pass Accuracy",
          homePercent: 82,
          awayPercent: 78,
        ),
        // Add more bars as needed...
      ],
    );
  }

  Widget buildStatComparisonBar({
    required String category,
    required double homePercent,
    required double awayPercent,
  }) {
    final totalPercent = homePercent + awayPercent;
    final homeFlex = (homePercent / totalPercent * 100).round();
    final awayFlex = 100 - homeFlex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          // Category label centered
          Center(
            child: Text(
              category.toUpperCase(),
              style: Body2_b.style,
            ),
          ),
          const SizedBox(height: 6),

          // Bar row
          Row(
            children: [
              Text("${homePercent.toInt()}%", style: Body2.style),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: homeFlex,
                        child: Container(height: 8, color: Colors.redAccent),
                      ),
                      Expanded(
                        flex: awayFlex,
                        child: Container(height: 8, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${awayPercent.toInt()}%", style: Body2.style),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("LINEUP", style: Body2_b.style),
        SizedBox(height: 12),
        SizedBox(
          height: 300,
          child: Placeholder(), // Replace with 2-team lineup layout
        ),
      ],
    );
  }

  Widget _buildSubstitutesAndCoach({
    required List<Substitute> subsA,
    required List<Substitute> subsB,
    required String coachA,
    required String coachB,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("SUBSTITUTES", style: Body2_b.style),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team A
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subsA.map((sub) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          sub.name,
                          style: Body1.style,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (sub.subIn) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_circle_left, size: 20, color: Colors.white),
                        ],
                        if (sub.minute != null) ...[
                          const SizedBox(width: 4),
                          Text("${sub.minute}’", style: Body1.style),
                        ],
                        if (sub.goal) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.sports_soccer, size: 20, color: Colors.white),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            // Team B
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: subsB.map((sub) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (sub.goal) const Icon(Icons.sports_soccer, size: 20, color: Colors.white),
                        if (sub.minute != null) ...[
                          const SizedBox(width: 4),
                          Text("${sub.minute}’", style: Body1.style),
                        ],
                        const SizedBox(width: 4),
                        if (sub.subIn) const Icon(Icons.arrow_circle_left, size: 20, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          sub.name,
                          style: Body1.style,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text("COACH", style: Body2_b.style),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(coachA, style: Body1.style),
            Text(coachB, style: Body1.style),
          ],
        ),
      ],
    );
  }

}