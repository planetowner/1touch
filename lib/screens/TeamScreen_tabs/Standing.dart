import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
// import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const StandingTab({super.key, required this.team});

  @override
  State<StandingTab> createState() => _StandingTabState();
}

class _StandingTabState extends State<StandingTab> {
  String selectedLeague = "LA LIGA";
  String selectedSeason = "24/25 season";
  bool isScrolledToEnd = false;

  final List<String> leagues = ["LA LIGA", "PREMIER LEAGUE", "SERIE A"];
  final List<String> seasons = ["23/24 season", "24/25 season", "25/26 season"];
  final ScrollController _horizontalScrollController = ScrollController();

  List<Map<String, dynamic>> standings = [];

  @override
  void initState() {
    super.initState();
    _loadStandings();

    _horizontalScrollController.addListener(() {
      final controller = _horizontalScrollController;
      final atEnd = controller.offset >= controller.position.maxScrollExtent - 4;

      if (isScrolledToEnd != atEnd) {
        setState(() {
          isScrolledToEnd = atEnd;
        });
      }
    });
  }

  void _loadStandings() {
    // Simulate fetching standings based on selectedLeague and selectedSeason
    setState(() {
      standings = List.generate(20, (index) {
        return {
          'rank': index + 1,
          'team': 'ABC',
          'mp': 38,
          'w': 20,
          'd': 10,
          'l': 8,
          'gf': 60,
          'ga': 40,
          'pts': 70,
        };
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 24),
                child: Row(
                  children: [
                    _buildDropdown(
                      selected: selectedLeague,
                      items: leagues,
                      onChanged: (val) {
                        setState(() {
                          selectedLeague = val!;
                          _loadStandings();
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildDropdown(
                      selected: selectedSeason,
                      items: seasons,
                      onChanged: (val) {
                        setState(() {
                          selectedSeason = val!;
                          _loadStandings();
                        });
                      },
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.only(left: 24, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text("STANDING", style: Body2_b.style,)
                  ],
                ),
              ),
              _buildStandingBox(),
              SizedBox(height: 144,)
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String selected,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: const Color(0xFF3D3D3D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF3D3D3D),
          style: Body2_b.style,
          onChanged: onChanged,
          items: items.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Text(e, style: Body2_b.style),
            );
          }).toList(),
        ),
      ),
    );
  }
  Widget _buildStandingBox() {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// FIXED LEFT SIDE: CLUB
            Container(
              color: Color(0xFF1E1E1E),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header — Club
                  Container(
                    width: 146,
                    color: const Color(0xFF3D3D3D),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(left: 24, right: 24, top:24, bottom: 16),
                    child: Text("Club", style: Body2.style),
                  ),
                  Container(height: 24,),
                  // Body Rows — Left Side
                  ...standings.map((team) {
                    return Container(
                      width: 146,
                      color: const Color(0xFF1E1E1E),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 24,
                            child: Text("${team['rank']}", style: Body2.style, textAlign: TextAlign.right),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(team['team'], style: Body2.style, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }),
                  Container(height: 24,),
                ],
              ),
            ),

            /// DIVIDER
            Container(width: 1, color: Colors.black),

            /// RIGHT SIDE: STATS (scrollable)
            Expanded(
              child: Container(
                color: Color(0xFF1E1E1E),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _horizontalScrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header — Stats
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          topRight: isScrolledToEnd ? Radius.circular(16) : Radius.zero,
                        ),
                        child: Container(
                          color: const Color(0xFF3D3D3D),
                          padding: const EdgeInsets.only(left: 24, right: 16, top: 24, bottom: 16),
                          child: Row(
                            children: [
                              _buildHeaderCell("MP"),
                              _buildHeaderCell("W"),
                              _buildHeaderCell("D"),
                              _buildHeaderCell("L"),
                              _buildHeaderCell("GF"),
                              _buildHeaderCell("GA"),
                              _buildHeaderCell("GD"),
                              _buildHeaderCell("Pts"),
                              _buildHeaderCell("Last 5", isWide: true),
                            ],
                          ),
                        ),
                      ),
                      Container(height: 24,),
                      // Body Rows — Stat Cells
                      ...standings.map((team) {
                        return Container(
                          color: const Color(0xFF1E1E1E),
                          padding: const EdgeInsets.only(left: 24, right: 16),
                          child: Row(
                            children: [
                              _buildStatCell("${team['mp']}"),
                              _buildStatCell("${team['w']}"),
                              _buildStatCell("${team['d']}"),
                              _buildStatCell("${team['l']}"),
                              _buildStatCell("${team['gf']}"),
                              _buildStatCell("${team['ga']}"),
                              _buildStatCell("${team['gf'] - team['ga']}"),
                              _buildStatCell("${team['pts']}"),
                              _buildLastFive(['W', 'W', 'D', 'L', 'W']),
                            ],
                          ),
                        );
                      }),
                      ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomRight: isScrolledToEnd ? Radius.circular(16) : Radius.zero,
                        ),
                        child: Container(
                          height: 24,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildLastFive(List<String> results) {
    return SizedBox(
      width: 100,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: results.map((r) {
          Color color;
          switch (r) {
            case 'W': color = Colors.blue; break;
            case 'D': color = Colors.grey; break;
            case 'L': color = Colors.red; break;
            default: color = Colors.white;
          }
          return Icon(Icons.check_circle, size: 19, color: color);
        }).toList(),
      ),
    );
  }
  Widget _buildHeaderCell(String title, {bool isWide = false}) {
    return Container(
      width: isWide ? 100 : 32,
      padding: EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      color: const Color(0xFF3D3D3D),
      child: Text(title, style: Body2.style),
    );
  }
  Widget _buildStatCell(String text, {bool isWide = false}) {
    return Container(
      width: isWide ? 100 : 32,
      padding: EdgeInsets.only(right: 8),
      // height: 44,
      alignment: Alignment.center,
      color: const Color(0xFF1E1E1E),
      child: Text(text, style: Body2.style),
    );
  }
}