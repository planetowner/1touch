import 'package:flutter/material.dart';
import 'package:onetouch/data/playerdata.dart'; // assuming Player model lives here
import 'package:onetouch/core/stylesheet_dark.dart';

class AnalysisTab extends StatelessWidget {
  final Player player;

  const AnalysisTab({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopStatsBlock(),
          const SizedBox(height: 48),
          _buildInfluenceBlock(),
          const SizedBox(height: 48,),
          _buildPerformanceChartPlaceholder(),
          const SizedBox(height: 48,),
          _buildAttributesBlockPlaceholder(),
          const SizedBox(height: 144,),
        ],
      ),
    );
  }

  Widget _buildTopStatsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TOP STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: "3",
                  label: "Goals",
                  rank: "#1",
                ),
              ),
              SizedBox(width: 9.5),
              Expanded(
                child: _StatBox(
                  value: "5",
                  label: "Assists",
                  rank: "#3",
                ),
              ),
              SizedBox(width: 9.5),
              Expanded(
                child: _StatBox(
                  value: "72%",
                  label: "Shot Accuracy",
                  rank: "#7",
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _StatBox({
    required String value,
    required String label,
    required String rank,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(value, style: Heading2.style),
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: Body1.style),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(rank, style: Body1.style),
        ),
      ],
    );
  }
  Widget _buildInfluenceBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("INFLUENCE", style: Body2_b.style),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.2,
          children: [
            _influenceCard("Starting Rate", "92", "%"),
            _influenceCard("Win Rate with\nHeungmin", "80", "%"),
            _influenceCard("Minutes Played\nPer Game", "80", "Min."),
            _influenceCard("Contribution to\nGoals", "18", "%"),
          ],
        ),
      ],
    );
  }

  Widget _influenceCard(String label, String value, String suffix) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Body1.style),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: Heading1.style),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(suffix, style: Body1.style),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildPerformanceChartPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("PERFORMANCE", style: Body2_b.style),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF3D3D3D),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Text("22/23", style: Body2_b.style),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            "Performance Chart\n(Coming Soon)",
            textAlign: TextAlign.center,
            style: Heading5.style,
          ),
        ),
      ],
    );
  }

  Widget _buildAttributesBlockPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with arrow
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("ATTRIBUTES", style: Body2_b.style),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
        const SizedBox(height: 16),
        // Placeholder container
        Container(
          height: 260,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            "Radar Chart\n(Coming Soon)",
            textAlign: TextAlign.center,
            style: Heading5.style,
          ),
        ),
      ],
    );
  }
}