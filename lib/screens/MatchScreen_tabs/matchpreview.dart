import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/betting_widgets.dart';

import 'package:fl_chart/fl_chart.dart';

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
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Text('Radar Chart Placeholder', style: TextStyle(color: Colors.white54)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("STANDING", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: List.generate(5, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("Team Name", style: TextStyle(color: Colors.white)),
                    Text("## ## ## ##", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}