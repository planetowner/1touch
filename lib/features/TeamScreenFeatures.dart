import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/teamdata.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/stylesheet_dark.dart";

import '../data/matchdata.dart';

class Fixtures extends StatefulWidget {
  Fixtures({super.key, this.teams});

  final teams;

  @override
  State<Fixtures> createState() => _FixturesState();
}

class _FixturesState extends State<Fixtures> {

  @override
  Widget build(BuildContext context) {
    MatchData? match;
    String leagueName = "Unknown League";

    if (widget.teams == null) {
      return const SizedBox.shrink();
    }
    if (widget.teams is Map<String, dynamic>) {
      final teamObj = Team.fromJson(widget.teams as Map<String, dynamic>);
      match = teamObj.nextMatch;
      leagueName = leagueNames[teamObj.leagueId] ?? "Unknown League";
    }

    if (match == null) return const SizedBox.shrink();


    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Material(
          elevation: 0,
          color: const Color(0xFF272828),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                color: Color(0xFF272828)
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    final matchId = match!.id.toString();
                    context.push('/match/$matchId');
                  },
                  child: MatchCard(
                    match: match,
                    leagueName: leagueName,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    const matchId = "300";
                    GoRouter.of(context)
                        .push('/match/$matchId'); // Navigate to MatchScreen
                  },
                  child: MatchCard2(
                    date: "Sun, Sep 15 10:15 AM",
                    venue: 'Venue Name',
                    team1shortname: "FCB",
                    team1Logo: "TeamLogos/Barcelona.png",
                    team2shortname: "GIR",
                    team2Logo: 'TeamLogos/Girona.png',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Standing extends StatefulWidget {
  const Standing({super.key, this.teams});
  final teams;

  @override
  _StandingState createState() => _StandingState();
}

class _StandingState extends State<Standing> {
  // colors
  static const Color _bodyColor    = Color(0xFF272828);
  static const Color _headerColor  = Color(0xFF3D3D3D);
  static const Color _dividerColor = Color(0xFF2B2B2B);

  // grid widths (tweak if needed)
  static const double _rankW = 32;
  static const double _gapW  = 16;
  static const double _statW = 28;

  final List<String> leagues = ["La Liga", "Champions League", "Super League"];

  // demo rows (3위 강조)
  final List<Map<String, dynamic>> rows = const [
    {"rank": 1, "team": "Team Name", "mp": "##", "w": "##", "d": "##", "l": "##", "hl": false},
    {"rank": 2, "team": "Team Name", "mp": "##", "w": "##", "d": "##", "l": "##", "hl": false},
    {"rank": 3, "team": "Team Name", "mp": "##", "w": "##", "d": "##", "l": "##", "hl": true },
    {"rank": 4, "team": "Team Name", "mp": "##", "w": "##", "d": "##", "l": "##", "hl": false},
    {"rank": 5, "team": "Team Name", "mp": "##", "w": "##", "d": "##", "l": "##", "hl": false},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(
            leagues.length,
                (i) => _buildStandingCard(
              leagues[i],
              isFirst: i == 0,
              isLast: i == leagues.length - 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStandingCard(String leagueName, {required bool isFirst, required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isFirst ? 24 : 0,
        right: isLast ? 24 : 16,
        top: 16,
        bottom: 16,
      ),
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 345,
          decoration: const BoxDecoration(color: _bodyColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header block
              Container(
                color: _headerColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24,),
                    // league title line
                    Row(
                      children: [
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDB0030),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(leagueName, style: Heading4.style),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // columns header line (uses same table grid as body)
                    _columnsHeader(),
                    SizedBox(height: 12,),
                  ],
                ),
              ),
              // divider
              Container(height: 1, color: _dividerColor),

              // body rows table (aligned with header)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _rowsTable(rows),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // shared columnWidths for perfect alignment
  Map<int, TableColumnWidth> get _grid => const {
    0: FixedColumnWidth(_rankW), // #
    1: FlexColumnWidth(),        // Club
    2: FixedColumnWidth(_gapW),  // gap
    3: FixedColumnWidth(_statW), // MP
    4: FixedColumnWidth(_statW), // W
    5: FixedColumnWidth(_statW), // D
    6: FixedColumnWidth(_statW), // L
  };

  Widget _columnsHeader() {
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: const [
        TableRow(
          children: [
            Text("#", style: TextStyle(color: Colors.white)),
            Text("Club", overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white)),
            SizedBox.shrink(),
            Align(alignment: Alignment.centerRight, child: Text("MP", style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("W",  style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("D",  style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("L",  style: TextStyle(color: Colors.white))),
          ],
        ),
      ],
    );
  }

  Widget _rowsTable(List<Map<String, dynamic>> data) {
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: data.map((r) {
        final bool hl = r["hl"] == true;
        final Color c = hl ? Colors.white : Colors.white54;
        final FontWeight w = hl ? FontWeight.w700 : FontWeight.w400;

        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8), // gap here
              child: Text("${r["rank"]}", style: TextStyle(color: c, fontWeight: w)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(r["team"], overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontWeight: w)),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["mp"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["w"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["d"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["l"], style: Heading5.style.copyWith(color: c))),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class BestXI extends StatefulWidget {
  const BestXI({super.key, this.teams});

  final teams;

  @override
  State<BestXI> createState() => _BestXIState();
}

class _BestXIState extends State<BestXI> {
  int mycolor = 0xFF3D3D3D;

  final List<List<String>> formation = [
    ["# Name"], // 1 Forward (ST)
    ["# Name", "# Name", "# Name"], // 3 Midfielders (CAM/CM)
    ["# Name", "# Name"], // 2 Midfielders (DM/CDM)
    ["# Name", "# Name", "# Name", "# Name"], // 4 Defenders (LB, CB, CB, RB)
    ["# Name"] // 1 Goalkeeper (GK)
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formation Box
          Material(
            elevation: 5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(mycolor),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children:
                    formation.map((row) => _buildFormationRow(row)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Builds each row of the formation
  Widget _buildFormationRow(List<String> players) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: players.map((name) => _buildPlayer(name)).toList(),
      ),
    );
  }

  // Player Circle with Name
  Widget _buildPlayer(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        children: [
          // Circle for player avatar
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Player name
          Text(
            name,
            style: Body2.style,
          ),
        ],
      ),
    );
  }
}

class InjuryStatus extends StatefulWidget {
  const InjuryStatus({super.key, this.teams});

  final teams;

  @override
  State<InjuryStatus> createState() => _InjuryStatusState();
}

class _InjuryStatusState extends State<InjuryStatus> {
  final List<Map<String, String>> injuredPlayers = [
    {
      'number': '10',
      'name': 'Player Name',
      'injury': 'Hamstring',
      'weeks': '3',
      'image': 'assets/messi.png',
    },
    {
      'number': '8',
      'name': 'Player Name',
      'injury': 'Ankle Sprain',
      'weeks': '5',
      'image': 'assets/messi.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...injuredPlayers
                .map((player) => _buildInjuryTile(player))
                ,
          ],
        ));
  }

  Widget _buildInjuryTile(Map<String, String> player) {
    return Container(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player Circle with Placeholder
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main player image circle
              CircleAvatar(
                radius: 37,
                backgroundImage: const AssetImage('assets/messi.png'),
                backgroundColor: Color(0xFF272828),
              ),

              // Jersey number in top-left badge
              Positioned(
                top: -5, // Slightly overlaps the top edge
                left: -10, // Slightly overlaps the left edge
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3D3D3D),
                  child: Text(player['number'] ?? '#', style: Body2_b.style),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player['name'] ?? '', style: Body1_b.style),
                const SizedBox(height: 4),
                Text('${player['injury']} • Back in ${player['weeks']} weeks',
                    style: Body2.style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Transfer extends StatefulWidget {
  const Transfer({super.key, this.teams});

  final teams;

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  bool showIn = true; // true = IN, false = OUT

  final List<Map<String, String>> inPlayers = [
    {
      'number': '10',
      'name': 'Player Name',
      'fee': '€100.0m',
      'oldteam': 'Team Name',
      'year': 'Feb 2025 – Jun 2025',
      'image': 'assets/messi.png',
    },
    {
      'number': '8',
      'name': 'Player Name',
      'fee': '€0.0m',
      'oldteam': 'Team Name',
      'year': 'Feb 2025 – Jun 2025',
      'image': 'assets/messi.png',
    },
  ];

  final List<Map<String, String>> outPlayers = [
    {
      'number': '7',
      'name': 'Player Name',
      'fee': '€20.0m',
      'oldteam': 'Team Name',
      'year': 'Feb 2025 – Jun 2025',
      'image': 'assets/messi.png',
    }
  ];

  @override
  Widget build(BuildContext context) {
    final players = showIn ? inPlayers : outPlayers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRANSFER SWITCH BUTTON
        Container(
          padding: EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => showIn = true),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: showIn ? Color(0xFF3D3D3D) : Colors.transparent,
                      border: Border.all(color: Color(0xFF3D3D3D)),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8)),
                    ),
                    alignment: Alignment.center,
                    child: Text("IN", style: Body2_b.style),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => showIn = false),
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !showIn ? Color(0xFF3D3D3D) : Colors.transparent,
                      border: Border.all(color: Color(0xFF3D3D3D)),
                      borderRadius: BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      "OUT",
                      style: Body2_b.style,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // PLAYER LIST
        ...players.map((player) => _buildTransferTile(player)),
      ],
    );
  }

  Widget _buildTransferTile(Map<String, String> player) {
    return Container(
      margin: EdgeInsets.only(left:24, right: 24, bottom: 16,top:8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player image and number badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundImage:
                    AssetImage(player['image'] ?? 'assets/messi.png'),
                backgroundColor: Color(0xFF272828),
              ),
              Positioned(
                top: -6,
                left: -10,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3D3D3D),
                  child: Text(player['number'] ?? '#', style: Body2_b.style),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(player['name'] ?? '', style: Heading5.style),
                    Text(player['fee'] ?? '', style: Heading5.style),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF3D3D3D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(showIn ? "FROM" : "TO", style: Eyebrow.style),
                    ),
                    const SizedBox(width: 8),
                    Text(player['oldteam'] ?? '', style: Body1.style),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF3D3D3D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text("CONTRACT", style: Eyebrow.style),
                    ),
                    const SizedBox(width: 8),
                    Text(player['year'] ?? '', style: Body1.style),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
