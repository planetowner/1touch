import 'package:flutter/material.dart';
import 'package:onetouch/data/playerdata.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';

class PlayerOverviewTab extends StatelessWidget {
  final Player player;

  const PlayerOverviewTab({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient behind player info
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 160,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  player.teamColor.withOpacity(1.0),
                  player.teamColor.withOpacity(0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Content on top of background
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBlock(player),
              const SizedBox(height: 48),
              _buildBioStatsBlock(context),
              const SizedBox(height: 48),
              _buildCompetitionsBlock(),
              const SizedBox(height: 48),
              _buildMatchSummaryBlock(),
              const SizedBox(height: 48),
              _buildClubHistoryBlock(),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBlock(Player player) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("7", style: Heading1.style),
            const SizedBox(height: 4),
            Text("LW • ST • LM", style: Body1.style),
            const SizedBox(height: 8),
            Text(player.teamName, style: Body1.style),
            const SizedBox(height: 4),
            Text("South Korea 🇰🇷", style: Body1.style),
          ],
        ),
        const Spacer(),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage("assets/img_2.png"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioStatsBlock(BuildContext context) {
    final double fullWidth = MediaQuery.of(context).size.width - 48; // 24px padding both sides

    return Wrap(
      spacing: 16,
      runSpacing: 24,
      children: [
        _buildStatBox("Height", "183cm", width: (fullWidth - 32) / 3),
        _buildStatBox("Weight", "78kg", width: (fullWidth - 32) / 3),
        _buildStatBox("Age", "31 yrs", width: (fullWidth - 32) / 3),
        _buildStatBox("Form", "Good", width: (fullWidth - 32) / 3),
        _buildStatBox("Market Value", "5.6M", width: (fullWidth - 32) / 3),
        _buildStatBox("Squad Role", "Captain", width: (fullWidth - 32) / 3),
        _buildStatBox("Market Value", "5.6M", width: (fullWidth - 32) / 3),
        _buildStatBox("Cost-Effectiveness", "Good", width: (fullWidth - 32)/3*2), // spans 2 columns
      ],
    );
  }

  Widget _buildStatBox(String label, String value, {required double width}) {
    return Container(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.2),
            margin: const EdgeInsets.only(bottom: 6),
          ),
          Row(
            children: [
              Text(label, style: Body2.style.copyWith(color: Colors.white)),
              if (label == "Cost-Effectiveness")
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(Icons.info_outline, size: 16, color: Colors.white),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: Heading5.style.copyWith(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildCompetitionsBlock() {
    final competitions = [
      {"name": "EPL", "mp": "###", "g": "###", "a": "###"},
      {"name": "UCL", "mp": "###", "g": "###", "a": "###"},
      {"name": "UEL", "mp": "###", "g": "###", "a": "###"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("COMPETITIONS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 0, 12),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: const [
                    Expanded(flex: 2, child: SizedBox()), // Empty to align with competition name
                    Expanded(
                      flex: 2,
                      child: Text("MP", style: Body1.style, textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("G", style: Body1.style, textAlign: TextAlign.center),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("A", style: Body1.style, textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              // Stat rows
              ...competitions.map((comp) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(comp["name"]!, style: Heading5.style),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(comp["mp"]!, style: Heading5.style, textAlign: TextAlign.center),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(comp["g"]!, style: Heading5.style, textAlign: TextAlign.center),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(comp["a"]!, style: Heading5.style, textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSummaryBlock() {
    final List<Map<String, dynamic>> matches = [
      {
        "result": "WIN",
        "score": "3 : 2",
        "minutes": "90 min.",
        "againstLogo": "assets/img.png",
        "stats": ["1 Goal", "1 Assist", "7.7"]
      },
      {
        "result": "LOST",
        "score": "3 : 2",
        "minutes": "78 min.",
        "againstLogo": "assets/img.png",
        "stats": ["92 Passes", "1 Assist", "7.7"]
      },
      {
        "result": "DRAW",
        "score": "3 : 2",
        "minutes": "45 min.",
        "againstLogo": "assets/img.png",
        "stats": ["1 Goal", "7.7"]
      },
      {
        "result": "WIN",
        "score": "3 : 2",
        "minutes": "90 min.",
        "againstLogo": "assets/img.png",
        "stats": ["1 Assist", "7.7"]
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MATCH SUMMARY", style: Body2_b.style),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
              decoration: BoxDecoration(
                color: Color(0xFF3D3D3D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: "22/23", // hardcoded for now
                  style: Body2_b.style,
                  dropdownColor: const Color(0xFF3D3D3D),
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  onChanged: (value) {
                    // Do nothing for now
                  },
                  items: const [
                    DropdownMenuItem(
                      value: "22/23",
                      child: Text("22/23", style: Body2_b.style),
                    ),
                    DropdownMenuItem(
                      value: "21/22",
                      child: Text("21/22", style: Body2_b.style),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: matches.map((match) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LEFT
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text("AGAINST", style: Body2_b.style),
                                  const SizedBox(width: 8),
                                  Image.asset(match["againstLogo"]!, width: 24, height: 24),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(match["minutes"]!, style: Heading5.style),
                            ],
                          ),
                        ),
                        // RIGHT
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(match["result"]!, style: Body2_b.style),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3D3D3D),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      match["score"]!,
                                      style: Heading5.style,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 12,
                                alignment: WrapAlignment.end,
                                children: (match["stats"]! as List<String>).map((stat) {
                                  return Text(stat, style: Heading5.style);
                                }).toList(),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (match != matches.last)
                    const Divider(color: Colors.white24, indent: 16, endIndent: 16, height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
  Widget _buildClubHistoryBlock() {
    final history = [
      {"year": "2015–", "club": "Tottenham Hotspurs"},
      {"year": "2013–2015", "club": "Bayer Leverkusen"},
      {"year": "2010–2013", "club": "Hamburg SV"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CLUB HISTORY", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: history.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry["year"]!, style: Body1.style),
                    Text(entry["club"]!, style: Heading5.style),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}