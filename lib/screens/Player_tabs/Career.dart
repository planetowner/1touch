import 'package:flutter/material.dart';
import 'package:onetouch/data/playerdata.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CareerTab extends StatelessWidget {
  final Player player;

  const CareerTab({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          _buildTrophyBlock(),
          const SizedBox(height: 48),
          _buildHistoryBlock(),
          const SizedBox(height: 144,),
        ],
      ),
    );
  }

  Widget _buildTrophyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /// Header row: TROPHIES + dropdown (optional in future)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("TROPHIES", style: Body2_b.style),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3D3D3D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Text("All", style: Body2_b.style),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        /// Trophy list block
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildClubHeader("FC Barcelona", "assets/barca_logo.svg",3),
              const SizedBox(height: 16),
              _buildTrophyItem("Spanish Champion", ["22/23"]),
              const SizedBox(height: 16),
              _buildTrophyItem("Spanish Super Cup", ["22/23", "24/25"]),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignCenter,
                      color: const Color(0xFF3D3D3D),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildClubHeader("Tottenham Hotspur", "assets/girona_logo.svg",1),
              const SizedBox(height: 16),
              _buildTrophyItem("EFL Cup", ["19/20"]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClubHeader(String clubName, String svgPath, int trophyCount) {
    return Row(
      children: [
        SvgPicture.asset(svgPath, width: 24, height: 24),
        const SizedBox(width: 8),
        Text("$clubName", style: Heading5.style),
        Spacer(),
        Text("$trophyCount", style: Heading5.style),
      ],
    );
  }

  Widget _buildTrophyItem(String title, List<String> seasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text("$title", style: Heading5.style),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seasons.map((season) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(season, style: Body2_b.style),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildHistoryBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("HISTORY", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            children: [
              _buildHistoryTeamBlock(
                period: "2022–Now",
                teamName: "Barcelona",
                expanded: true,
                seasons: [
                  {"season": "24/25", "matches": "44", "wr": "76%", "rating": "8.4"},
                  {"season": "23/24", "matches": "36", "wr": "72%", "rating": "8.1"},
                  {"season": "22/23", "matches": "40", "wr": "70%", "rating": "7.7"},
                ],
              ),
              _buildDivider(),
              _buildHistoryTeamBlock(
                period: "2020–2022",
                teamName: "Leeds United",
                expanded: false,
              ),
              _buildDivider(),
              _buildHistoryTeamBlock(
                period: "2019–2020",
                teamName: "Stade Rennais",
                expanded: false,
              ),
              _buildDivider(),
              _buildHistoryTeamBlock(
                period: "2018–2019",
                teamName: "Sporting CP",
                expanded: false,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildHistoryTeamBlock({
    required String period,
    required String teamName,
    bool expanded = false,
    List<Map<String, String>>? seasons,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(period, style: Body1.style),
            const SizedBox(width: 8),
            Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
            const Spacer(),
            Text(teamName, style: Heading5.style),
          ],
        ),
        if (expanded && seasons != null)
          ...seasons.map((season) {
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text(season["season"]!, style: Body1.style),
                  Spacer(),
                  Text("${season["matches"]} Matches", style: Body1_b.style),
                  const SizedBox(width: 12),
                  Text("WR ${season["wr"]}", style: Body1_b.style),
                  const SizedBox(width: 12),
                  Text(season["rating"]!, style: Heading5.style),
                ],
              ),
            );
          }).toList()
      ],
    );
  }

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Colors.white24),
    );
  }
}