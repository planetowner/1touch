import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
// import 'package:go_router/go_router.dart';
// import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class AnalysisTab extends StatelessWidget {
  final Map<String, dynamic>? team;

  const AnalysisTab({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BestElevenSection(),
          CurrentFormSection(),
          ProbabilitySection(),
        ],
      ),
    );
  }
}

class BestElevenSection extends StatefulWidget {
  const BestElevenSection({super.key});

  @override
  State<BestElevenSection> createState() => _BestElevenSectionState();
}

class _BestElevenSectionState extends State<BestElevenSection> {
  String selectedFormation = "4-2-3-1 (90%)";

  final List<String> formations = [
    "4-2-3-1 (90%)",
    "4-3-3 (88%)",
    "3-5-2 (82%)",
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BEST ELEVEN", style: Body2_b.style),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFormation,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    dropdownColor: const Color(0xFF3D3D3D),
                    style: Body2_b.style,
                    onChanged: (val) {
                      setState(() => selectedFormation = val!);
                    },
                    items: formations.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(f),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Formation Grid (hardcoded 4-2-3-1)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                _formationRow(["# Name"]),
                const SizedBox(height: 24), // more spacing
                _formationRow(["# Name", "# Name", "# Name"]),
                const SizedBox(height: 24),
                _formationRow(["# Name", "# Name"]),
                const SizedBox(height: 24),
                _formationRow(["# Name", "# Name", "# Name", "# Name"]),
                const SizedBox(height: 24),
                _formationRow(["# Name"]),
              ],
            )
          )
        ],
      ),
    );
  }

  Widget _formationRow(List<String> players) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: players.map((name) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 4),
                Text(name, style: Body2.style),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class CurrentFormSection extends StatefulWidget {
  const CurrentFormSection({super.key});

  @override
  State<CurrentFormSection> createState() => _CurrentFormSectionState();
}

class _CurrentFormSectionState extends State<CurrentFormSection> {
  String selectedSeason = "22/23";

  final List<String> seasons = ["22/23", "21/22", "20/21"];

  // Dummy matchday data: x = round, y = cumulative points
  final List<FlSpot> currentSeasonPoints = [
    FlSpot(1, 3),
    FlSpot(2, 6),
    FlSpot(3, 7),
    FlSpot(4, 10),
    FlSpot(5, 13),
  ];

  final Map<String, List<FlSpot>> previousSeasonData = {
    "22/23": [
      FlSpot(1, 1),
      FlSpot(2, 4),
      FlSpot(3, 6),
      FlSpot(4, 8),
      FlSpot(5, 9),
    ],
    "21/22": [
      FlSpot(1, 2),
      FlSpot(2, 3),
      FlSpot(3, 5),
      FlSpot(4, 9),
      FlSpot(5, 11),
    ],
    "20/21": [
      FlSpot(1, 3),
      FlSpot(2, 5),
      FlSpot(3, 6),
      FlSpot(4, 6),
      FlSpot(5, 7),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final previousSeasonPoints = previousSeasonData[selectedSeason]!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CURRENT FORM", style: Body2_b.style),
              Spacer(),
              Text("VS.", style: Body2_b.style),
              SizedBox(width: 4,),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSeason,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    dropdownColor: const Color(0xFF3D3D3D),
                    style: Body2_b.style,
                    onChanged: (val) {
                      setState(() => selectedSeason = val!);
                    },
                    items: seasons.map((s) {
                      return DropdownMenuItem(value: s, child: Text(s));
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Axis Labels (Point + Round)

          // 📈 Chart Container
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // 📈 Chart + Vertical "Point" label side by side
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ⬅️ Rotated "Point" on the left
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Transform.rotate(
                        angle: -math.pi / 2,
                        child: Text("Point", style: Body2.style),
                      ),
                    ),

                    // 📊 The actual chart
                    Expanded(
                      child: SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: Colors.white.withOpacity(0.1),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 5,
                                  getTitlesWidget: (value, meta) => Text(
                                    "${value.toInt()}",
                                    style: Body2.style,
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) => Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text("MD ${value.toInt()}", style: Body2.style),
                                  ),
                                ),
                              ),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                spots: currentSeasonPoints,
                                isCurved: false,
                                barWidth: 3,
                                color: Colors.redAccent,
                                dotData: FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: previousSeasonPoints,
                                isCurved: false,
                                barWidth: 2,
                                color: Colors.white,
                                dashArray: [6, 4],
                                dotData: FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text("Round", style: Body2.style),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class ProbabilitySection extends StatelessWidget {
  const ProbabilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 144),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PROBABILITY", style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _probabilityBox(
                  title: "Chances to win\nUCL Trophy",
                  value: 16,
                  delta: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _probabilityBox(
                  title: "Chances to win\nLEAGUE Trophy",
                  value: 32,
                  delta: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _probabilityBox({
    required String title,
    required int value,
    required int delta,
  }) {
    final bool isUp = delta >= 0;
    final IconData arrow = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    final Color arrowColor = isUp ? Colors.blueAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Body1.style),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$value",
                style: Heading1.style,
              ),
              Text(
                "%",
                style: Heading4.style,
              ),
              Spacer(),
              Row(
                children: [
                  Icon(arrow, color: arrowColor, size: 24),
                  Text(
                    "$delta",
                    style: Heading5.style,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

