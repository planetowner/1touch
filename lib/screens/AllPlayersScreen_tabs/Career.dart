import 'package:flutter/material.dart';
import 'package:onetouch/data/playerdata.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';

class CareerTab extends StatefulWidget {
  final Player player;

  const CareerTab({super.key, required this.player});

  @override
  State<CareerTab> createState() => _CareerTabState();
}

class _CareerTabState extends State<CareerTab> {
  String _trophyFilter = "TEAM"; // TEAM or PERSONAL

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
          const SizedBox(height: 144),
        ],
      ),
    );
  }

  Widget _buildTrophyBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("TROPHIES", style: Body2_b.style),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      ["TEAM", "PERSONAL"].map((option) {
                        return ListTile(
                          title: Text(
                            option,
                            style: Body2_b.style.copyWith(
                              color: _trophyFilter == option
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                          trailing: _trophyFilter == option
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                          onTap: () {
                            setState(() => _trophyFilter = option);
                            Navigator.pop(context);
                          },
                        );
                      }).toList() as Widget, // won't work — see below
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(_trophyFilter, style: Body2_b.style),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: _trophyFilter == "TEAM"
              ? _buildTeamTrophies()
              : _buildPersonalTrophies(),
        ),
      ],
    );
  }

  Widget _buildTeamTrophies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClubHeader("FC BARCELONA", "TeamLogos/Barcelona.png", 3),
        const SizedBox(height: 16),
        _buildTrophyItem("Spanish Champion", ["22/23"]),
        const SizedBox(height: 16),
        _buildTrophyItem("Spanish Super Cup", ["22/23", "24/25"]),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: Colors.white12),
        ),
        _buildClubHeader("SPORTING CP", "TeamLogos/SportingCP.png", 2),
        const SizedBox(height: 16),
        _buildTrophyItem("Portuguese Cup", ["19/20"]),
        const SizedBox(height: 16),
        _buildTrophyItem("Portuguese League Cup", ["18/19"]),
      ],
    );
  }

  Widget _buildPersonalTrophies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrophyItem("Golden Boot", ["22/23"]),
        const SizedBox(height: 16),
        _buildTrophyItem("Best XI", ["22/23", "21/22"]),
      ],
    );
  }

  Widget _buildClubHeader(String clubName, String path, int trophyCount) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
          ),
          child: ClipRRect(
            child: Image.asset(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
              width: 32,  // Replaced 'size' with width
              height: 32, // Replaced 'size' with height
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(clubName, style: Body2_b.style),
        const Spacer(),
        Text("$trophyCount", style: Body2_b.style),
      ],
    );
  }

  Widget _buildTrophyItem(String title, List<String> seasons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(title, style: Heading5.style),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: seasons.map((season) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(season, style: Body2_b.style),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _leagueFilter = "ALL LEAGUES";
  Set<String> _expandedSeasons = {"24/25"}; // 24/25 is expanded by default

  final List<Map<String, dynamic>> _historyData = [
    {
      "season": "24/25",
      "teamLogo": "TeamLogos/Barcelona.png",
      "teamAbbr": "BAR",
      "mp": "44",
      "wr": "76%",
      "rating": "8.4",
      "subLeagues": [
        {"name": "LA LIGA", "mp": "30", "wr": "76%", "rating": "8.4"},
        {"name": "UCL", "mp": "9", "wr": "76%", "rating": "8.4"},
        {"name": "COPA DEL REY", "mp": "4", "wr": "72%", "rating": "8.1"},
        {"name": "SUPER CUP", "mp": "1", "wr": "70%", "rating": "7.7"},
      ],
    },
    {
      "season": "23/24",
      "teamLogo": "TeamLogos/Barcelona.png",
      "teamAbbr": "BAR",
      "mp": "36",
      "wr": "72%",
      "rating": "8.1",
      "subLeagues": [],
    },
    {
      "season": "22/23",
      "teamLogo": "TeamLogos/Barcelona.png",
      "teamAbbr": "BAR",
      "mp": "40",
      "wr": "70%",
      "rating": "7.7",
      "subLeagues": [],
    },
    {
      "season": "21/22",
      "teamLogo": "TeamLogos/Leeds.png",
      "teamAbbr": "LUFC",
      "mp": "40",
      "wr": "70%",
      "rating": "7.7",
      "subLeagues": [],
    },
    {
      "season": "20/21",
      "teamLogo": "TeamLogos/Leeds.png",
      "teamAbbr": "LUFC",
      "mp": "40",
      "wr": "70%",
      "rating": "7.7",
      "subLeagues": [],
    },
    {
      "season": "19/20",
      "teamLogo": "TeamLogos/Rennes.png",
      "teamAbbr": "SRFC",
      "mp": "40",
      "wr": "70%",
      "rating": "7.7",
      "subLeagues": [],
    },
    {
      "season": "18/19",
      "teamLogo": "TeamLogos/SportingCP.png",
      "teamAbbr": "SCP",
      "mp": "40",
      "wr": "70%",
      "rating": "7.7",
      "subLeagues": [],
    },
  ];

  Widget _buildHistoryBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("HISTORY", style: Body2_b.style),
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF2A2A2A),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      ...["ALL LEAGUES", "LA LIGA", "UCL", "COPA DEL REY"].map((option) {
                        return ListTile(
                          title: Text(
                            option,
                            style: Body2_b.style.copyWith(
                              color: _leagueFilter == option
                                  ? Colors.white
                                  : Colors.white54,
                            ),
                          ),
                          trailing: _leagueFilter == option
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                          onTap: () {
                            setState(() => _leagueFilter = option);
                            Navigator.pop(context);
                          },
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(_leagueFilter, style: Body2_b.style),
                    const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white, size: 20),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              // Table header
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text("Season",
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text("Team",
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("MP",
                          textAlign: TextAlign.center,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("WR",
                          textAlign: TextAlign.center,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("Rating",
                          textAlign: TextAlign.center,
                          style: Body2.style.copyWith(color: Colors.white54)),
                    ),
                    const SizedBox(width: 24), // space for arrow
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              // Data rows
              ..._historyData.asMap().entries.map((entry) {
                final data = entry.value;
                final season = data["season"] as String;
                final isExpanded = _expandedSeasons.contains(season);
                final subLeagues = (data["subLeagues"] as List<dynamic>).cast<Map<String, dynamic>>();
                final hasSubLeagues = subLeagues.isNotEmpty;

                return Column(
                  children: [
                    // Main row
                    InkWell(
                      onTap: hasSubLeagues
                          ? () {
                        setState(() {
                          if (isExpanded) {
                            _expandedSeasons.remove(season);
                          } else {
                            _expandedSeasons.add(season);
                          }
                        });
                      }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            // Season
                            Expanded(
                              flex: 2,
                              child: Text(season, style: Body2_b.style),
                            ),
                            // Team logo + abbr
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3D3D3D),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.asset(
                                        data["teamLogo"] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(data["teamAbbr"] as String,
                                      style: Body2_b.style),
                                ],
                              ),
                            ),
                            // MP
                            Expanded(
                              flex: 2,
                              child: Text(data["mp"] as String,
                                  textAlign: TextAlign.center,
                                  style: Body2_b.style),
                            ),
                            // WR
                            Expanded(
                              flex: 2,
                              child: Text(data["wr"] as String,
                                  textAlign: TextAlign.center,
                                  style: Body2_b.style),
                            ),
                            // Rating badge
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(data["rating"] as String,
                                      style: Body2_b.style),
                                ),
                              ),
                            ),
                            // Arrow
                            SizedBox(
                              width: 24,
                              child: hasSubLeagues
                                  ? Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.white,
                                size: 18,
                              )
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Sub-league rows
                    if (isExpanded && hasSubLeagues)
                      ...subLeagues.map((sub) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              // Muted league name
                              Expanded(
                                flex: 5,
                                child: Text(
                                  sub["name"] as String,
                                  style:
                                  Body2.style.copyWith(color: Colors.white38),
                                ),
                              ),
                              // MP
                              Expanded(
                                flex: 2,
                                child: Text(sub["mp"] as String,
                                    textAlign: TextAlign.center,
                                    style: Body2.style
                                        .copyWith(color: Colors.white54)),
                              ),
                              // WR
                              Expanded(
                                flex: 2,
                                child: Text(sub["wr"] as String,
                                    textAlign: TextAlign.center,
                                    style: Body2.style
                                        .copyWith(color: Colors.white54)),
                              ),
                              // Rating
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(sub["rating"] as String,
                                      style: Body2_b.style),
                                ),
                              ),
                              const SizedBox(width: 24),
                            ],
                          ),
                        );
                      }),
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

  Widget _buildDivider() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: Colors.white24),
    );
  }
}