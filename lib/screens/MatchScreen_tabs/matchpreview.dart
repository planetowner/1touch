import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/betting_widgets.dart';

import 'package:fl_chart/fl_chart.dart';

class _StandingRow {
  final int pos;
  final String name;
  final String logo;
  final String mp;
  final String w;
  final String d;
  final String l;
  final bool highlight;

  const _StandingRow({
    required this.pos,
    required this.name,
    required this.logo,
    required this.mp,
    required this.w,
    required this.d,
    required this.l,
    required this.highlight,
  });
}

class MatchPreviewTab extends StatefulWidget {
  final String matchId;

  const MatchPreviewTab({super.key, required this.matchId});

  @override
  State<MatchPreviewTab> createState() => _MatchPreviewTabState();
}

class _MatchPreviewTabState extends State<MatchPreviewTab> {
  // Hardcoded for UI demo
  final int userBalance = 1200;

  void _openBettingModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Using the widget from the new file
        return BettingFlowModal(userBalance: userBalance);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildHeader(),
          const SizedBox(height: 48),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: Text(
              "BET",
              style: Body2_b.style,
            ),
          ),
          const SizedBox(height: 16),

          // Using the extracted widget from the new file
          MatchBettingSection(
            userBalance: userBalance,
            onPlaceBet: _openBettingModal,
          ),

          const SizedBox(height: 48),
          _buildRadarChart(),
          const SizedBox(height: 48),
          _buildLatestH2H(),
          const SizedBox(height: 48),
          _buildStandingTable(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTeamBlock("FCB", "TeamLogos/Barcelona.png"),
        Column(
          children: [
            Text('Sun, Apr 27', style: Body2.style),
            Text('3:00 PM', style: Body2.style),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.30,
              child: Container(
                width: 24,
                decoration: const ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 1, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Venue Name', style: Body2.style),
          ],
        ),
        _buildTeamBlock("GIR", "TeamLogos/Girona.png"),
      ],
    );
  }

  Widget _buildTeamBlock(String name, String logoPath) {
    return Column(
      children: [
        Image.asset(logoPath, width: 72, height: 72),
        const SizedBox(height: 4),
        Text(name, style: Body1.style),
      ],
    );
  }

  Widget _buildRadarChart() {
    return Column(
      children: [
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              tickCount: 4,

              // Grid rings
              gridBorderData: BorderSide(
                color: Colors.white.withOpacity(0.30), // white 12%
                width: 1,
              ),
              // Outermost ring
              radarBorderData: BorderSide(
                color: Colors.white.withOpacity(0.30),
                width: 1,
              ),
              // Tick rings (same as grid)
              tickBorderData: BorderSide(
                color: Colors.white.withOpacity(0.30),
                width: 1,
              ),

              // Hide tick value labels on each ring
              ticksTextStyle: const TextStyle(
                color: Colors.transparent,
                fontSize: 0,
              ),

              // Axis labels
              getTitle: (index, angle) {
                const labels = [
                  'Attack',
                  'Progression',
                  'Pressure',
                  'Dominance',
                  'Defense',
                  'Possession',
                ];
                return RadarChartTitle(
                  text: labels[index],
                  angle: 0, // keep all labels upright
                );
              },
              titleTextStyle: Eyebrow.style,
              titlePositionPercentageOffset: 0.15,

              dataSets: [
                // Barcelona
                RadarDataSet(
                  fillColor: const Color(0xFFE8434A).withOpacity(0.3),
                  borderColor: const Color(0xFFE8434A),
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: const [
                    RadarEntry(value: 85), // Attack
                    RadarEntry(value: 75), // Progression
                    RadarEntry(value: 55), // Pressure
                    RadarEntry(value: 70), // Dominance
                    RadarEntry(value: 80), // Defense
                    RadarEntry(value: 65), // Possession
                  ],
                ),
                // Girona
                RadarDataSet(
                  fillColor: Colors.white.withOpacity(0.10),
                  borderColor: Colors.white.withOpacity(0.85),
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: const [
                    RadarEntry(value: 55),
                    RadarEntry(value: 60),
                    RadarEntry(value: 75),
                    RadarEntry(value: 50),
                    RadarEntry(value: 60),
                    RadarEntry(value: 72),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendDot(const Color(0xFFE8434A), 'BARCELONA'),
            const SizedBox(width: 16),
            _buildLegendDot(Colors.white, 'GIRONA'),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Body2_b.style
        ),
      ],
    );
  }

  Widget _buildLatestH2H() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LATEST H2H", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSimpleTeamCol("FCB", "TeamLogos/Barcelona.png"),
              const SizedBox(height: 8),
              _buildScoreBox('#'),
              Column(
                children: [
                  Text("Sun, Sep 15", style: Body2.style),
                  Text("10:15 AM", style: Body2.style),
                ],
              ),
              _buildScoreBox('#'),
              const SizedBox(height: 8),
              _buildSimpleTeamCol("GIR", "TeamLogos/Girona.png"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTeamCol(String name, String asset) {
    return Column(
      children: [
        Image.asset(asset, width: 48, height: 48),
        const SizedBox(height: 4),
        Text(name, style: Body2.style),
      ],
    );
  }

  Widget _buildScoreBox(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: Heading3.style),
    );
  }

  Widget _buildStandingTable() {
    const rows = [
      _StandingRow(pos: 1,  name: 'Team Name', logo: 'TeamLogos/placeholder.png', mp: '##', w: '##', d: '##', l: '##', highlight: false),
      _StandingRow(pos: 2,  name: 'Team Name', logo: 'TeamLogos/placeholder.png', mp: '##', w: '##', d: '##', l: '##', highlight: false),
      _StandingRow(pos: 3,  name: 'Team Name', logo: 'TeamLogos/Barcelona.png',   mp: '##', w: '##', d: '##', l: '##', highlight: true),
      _StandingRow(pos: 4,  name: 'Team Name', logo: 'TeamLogos/placeholder.png', mp: '##', w: '##', d: '##', l: '##', highlight: false),
      _StandingRow(pos: 5,  name: 'Team Name', logo: 'TeamLogos/placeholder.png', mp: '##', w: '##', d: '##', l: '##', highlight: false),
      _StandingRow(pos: 12, name: 'Team Name', logo: 'TeamLogos/Girona.png',       mp: '##', w: '##', d: '##', l: '##', highlight: true),
    ];
    const int dividerIndex = 5; // "..." appears before this index

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("STANDING", style: Body2_b.style),
        const SizedBox(height: 16),
        // ── HEADER BOX: rounded top corners only ──
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3D3D3D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League logo + name
              Row(
                children: [
                  Image.asset(
                    'LeagueLogos/laliga.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.sports_soccer,
                      color: Color(0xFFE8434A),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'La Liga',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Column labels
              Row(
                children: [
                  const SizedBox(
                    width: 32,
                    child: Text('#',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  const Expanded(
                    child: Text('Club',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ),
                  ..._colLabel('MP'),
                  ..._colLabel('W'),
                  ..._colLabel('D'),
                  ..._colLabel('L'),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.black.withOpacity(0.40)),
            ],
          ),
        ),
        // ── BODY BOX: rounded bottom corners only ──
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF3D3D3D),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: List.generate(rows.length, (i) {
              final row = rows[i];
              return Column(
                children: [
                  if (i == dividerIndex)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          '• • •',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  _buildStandingRowWidget(row),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _colLabel(String text) => [
    SizedBox(
      width: 32,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ),
  ];

  Widget _buildStandingRowWidget(_StandingRow row) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );
    final mutedStyle = TextStyle(
      color: row.highlight ? Colors.white : Colors.grey,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 28,
            child: Text(
              '${row.pos}',
              style: mutedStyle,
            ),
          ),
          // Logo + name
          Expanded(
            child: Row(
              children: [
                Image.asset(
                  row.logo,
                  width: 20,
                  height: 20,
                  errorBuilder: (_, __, ___) => Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(row.name, style: textStyle),
              ],
            ),
          ),
          // MP W D L
          for (final val in [row.mp, row.w, row.d, row.l])
            SizedBox(
              width: 32,
              child: Text(
                val,
                textAlign: TextAlign.center,
                style: mutedStyle,
              ),
            ),
        ],
      ),
    );
  }
}