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
          width: 145,
          height: 145,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: DecorationImage(
              fit: BoxFit.cover,
              image: AssetImage("assets/HeungminSon.png"),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBioStatsBlock(BuildContext context) {
    final stats = [
      {"label": "Height", "value": "183cm", "icon": null},
      {"label": "Weight", "value": "78kg", "icon": null},
      {"label": "Age", "value": "31 yrs", "icon": null},
      {"label": "Form", "value": "Fair", "icon": "refresh"},
      {"label": "Market Value", "value": "5.6M", "icon": null},
      {"label": "Squad Role", "value": "Captain", "icon": null},
      {"label": "Market Value", "value": "5.6M", "icon": null},
      {"label": "Cost-Effectiveness", "value": "Very Good", "icon": "refresh", "infoOnLabel": true},
    ];

    // Split into rows of 3
    List<List<Map<String, dynamic>>> rows = [];
    for (int i = 0; i < stats.length; i += 3) {
      rows.add(stats.sublist(i, i + 3 > stats.length ? stats.length : i + 3));
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final rowIndex = entry.key;
          final row = entry.value;

          return Column(
            children: [
              if (rowIndex != 0)
                const Divider(color: Colors.white12, height: 24),
              Row(
                children: row.asMap().entries.map((cellEntry) {
                  final cellIndex = cellEntry.key;
                  final stat = cellEntry.value;
                  final isLast = cellIndex == row.length - 1;
                  final isWide = row.length == 1 || (row.length == 2 && cellIndex == 1);

                  return Expanded(
                    flex: (stat["label"] == "Cost-Effectiveness") ? 2 : 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Label row
                              Row(
                                children: [
                                  Text(
                                    stat["label"] as String,
                                    style: Body2.style.copyWith(color: Colors.white54),
                                  ),
                                  if (stat["infoOnLabel"] == true)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(Icons.info_outline, size: 14, color: Colors.white54),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Value row
                              Row(
                                children: [
                                  Text(
                                    stat["value"] as String,
                                    style: Heading5.style,
                                  ),
                                  if (stat["icon"] == "refresh")
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(Icons.refresh, size: 16, color: Colors.white70),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white12,
                            margin: const EdgeInsets.only(right: 12),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompetitionsBlock() {
    final competitions = [
      {"name": "EPL", "mp": "###", "wr": "###", "rating": "8.4"},
      {"name": "UCL", "mp": "###", "wr": "###", "rating": "8.4"},
      {"name": "UEL", "mp": "###", "wr": "###", "rating": "8.4"},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("COMPETITION STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text("League", style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("MP", textAlign: TextAlign.center, style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("WR", textAlign: TextAlign.center, style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("Rating", textAlign: TextAlign.right, style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Stat rows
              ...competitions.asMap().entries.map((entry) {
                final comp = entry.value;
                final isLast = entry.key == competitions.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(comp["name"]!, style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(comp["mp"]!, textAlign: TextAlign.center, style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(comp["wr"]!, textAlign: TextAlign.center, style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D3D3D),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(comp["rating"]!, style: Heading5.style),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      const Divider(color: Colors.white12, height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSummaryBlock() {
    final List<Map<String, dynamic>> matches = [
      {
        "result": "DEF",
        "score": "0-2",
        "competition": "League / Round",
        "againstLogo": "assets/placeholder_team.png",
        "stats": [
          {"label": "Goal", "value": "1"},
          {"label": "Assist", "value": "2"},
          {"label": "Pass", "value": "83"},
        ],
        "rating": "8.4",
      },
      {
        "result": "DEF",
        "score": "0-2",
        "competition": "League / Round",
        "againstLogo": "assets/placeholder_team.png",
        "stats": [
          {"label": "Goal", "value": "1"},
          {"label": "Assist", "value": "2"},
          {"label": "Pass", "value": "83"},
        ],
        "rating": "8.4",
      },
      {
        "result": "DEF",
        "score": "0-2",
        "competition": "League / Round",
        "againstLogo": "assets/placeholder_team.png",
        "stats": [
          {"label": "Goal", "value": "1"},
          {"label": "Assist", "value": "2"},
          {"label": "Pass", "value": "83"},
        ],
        "rating": "8.4",
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MATCHES", style: Body2_b.style),
            const Icon(Icons.chevron_right, color: Colors.white, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        // Each match is its own card
        ...matches.map((match) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Top row: logo + result/score + competition
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF3D3D3D),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            match["againstLogo"] as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${match["result"]}  ( ${match["score"]} )",
                        style: Heading5.style,
                      ),
                      const Spacer(),
                      Text(
                        match["competition"] as String,
                        style: Body2.style.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 12),
                  // Bottom row: label + value pill, rating badge
                  Row(
                    children: [
                      // Stat pairs
                      ...(match["stats"] as List<Map<String, String>>).map((stat) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                stat["label"]!,
                                style: Body2.style.copyWith(color: Colors.white54),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3D3D3D),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  stat["value"]!,
                                  style: Body2_b.style,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Spacer(),
                      // Rating badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D3D3D),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          match["rating"] as String,
                          style: Heading5.style,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClubHistoryBlock() {
    final history = [
      {
        "year": "2015–",
        "club": "Tottenham Hotspur",
        "logo": "TeamLogos/Tottenham.png",
      },
      {
        "year": "2013–2015",
        "club": "Bayer Leverkusen",
        "logo": "TeamLogos/BayerLeverkusen.png",
      },
      {
        "year": "2010–2013",
        "club": "Hamburg SV",
        "logo": "TeamLogos/Hamburger.png",
      },
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
          child: Column(
            children: history.asMap().entries.map((entry) {
              final isLast = entry.key == history.length - 1;
              final club = entry.value;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Team logo
                        Container(
                          width: 24,
                          height: 24,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              club["logo"]!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Club name
                        Expanded(
                          child: Text(club["club"]!, style: Heading5.style),
                        ),
                        // Year
                        Text(
                          club["year"]!,
                          style: Body1.style,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}