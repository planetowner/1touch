import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class MatchPreviewTab extends StatefulWidget {
  final String matchId;

  const MatchPreviewTab({super.key, required this.matchId});

  @override
  State<MatchPreviewTab> createState() => _MatchPreviewTabState();
}

class _MatchPreviewTabState extends State<MatchPreviewTab> {
  String selectedResult = 'Draw'; // Win / Draw / Lose
  int selectedPoints = 100;

  final List<String> resultOptions = ['Win', 'Draw', 'Lose'];
  final List<int> pointValues = [100, 500, 1000];

  void _showBetConfirmationDialog(BuildContext context, String selectedPoints, String selectedResult) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: false,
      backgroundColor: const Color(0xFF272828),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  text: 'Are you sure you want to bet the following\namount on ',
                  style: Body1.style,
                  children: [
                    TextSpan(
                      text: '$selectedResult?',
                      style: Body1.style,
                    )
                  ],
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  selectedPoints,
                  style: Heading3.style,
                  textAlign: TextAlign.center,
                ),
              ),
              // ... rest remains unchanged ...
            ],
          ),
        );
      },
    );
  }

  void _showResultPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF3D3D3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: resultOptions.map((option) {
            return ListTile(
              title: Center(child: Text(option, style: Body1_b.style)),
              onTap: () {
                setState(() => selectedResult = option);
                Navigator.pop(context);
              },
            );
          }).toList(),
        );
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
          const Text(
            "BET",
            style: Body2_b.style,
          ),
          const SizedBox(height: 16),
          _buildBetSection(),
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
        _buildTeamBlock("FCB", "assets/barca_logo.svg"),
        Column(
          children: [
            Text('Sun, Apr 27', style: Body2.style),
            Text('3:00 PM', style: Body2.style),
            SizedBox(height: 8),
            Opacity(
              opacity: 0.30,
              child: Container(
                width: 24,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: 1,
                      strokeAlign: BorderSide.strokeAlignCenter,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Text('Venue Name', style: Body2.style),
          ],
        ),
        _buildTeamBlock("GIR", "assets/girona_logo.svg"),
      ],
    );
  }

  Widget _buildTeamBlock(String name, String logoPath) {
    return Column(
      children: [
        SvgPicture.asset(logoPath, width: 72, height: 72),
        const SizedBox(height: 4),
        Text(name, style: Body1.style),
      ],
    );
  }

  Widget _buildBetSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 🟦 Top H2H row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTeamLogo('FCB', 'assets/barca_logo.svg'),
              _buildStatBox('###'),
              _buildStatBox('###'),
              _buildStatBox('###'),
              _buildTeamLogo('BBB', 'assets/girona_logo.svg'),
            ],
          ),
          const SizedBox(height: 4),
          // 🟩 W D L below boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(width: 72), // for left logo
              SizedBox(width: 64, child: Center(child: Text("W", style: Body2.style))),
              SizedBox(width: 64, child: Center(child: Text("D", style: Body2.style))),
              SizedBox(width: 64, child: Center(child: Text("L", style: Body2.style))),
              SizedBox(width: 72), // for right logo
            ],
          ),

          const SizedBox(height: 24),

          // 🟨 Dropdown Row (Result + Points)
          Row(
            children: [
              Expanded(
                child: _buildDropdownBox(
                  label: selectedResult,
                  onTap: () => _showResultPicker(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPointsSelector(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 🟥 Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                _showBetConfirmationDialog(context, "$selectedPoints Pts", selectedResult);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "BET",
                style: TextStyle(
                  color: Color(0xFF090A0A),
                  fontSize: 14,
                  fontFamily: 'Archivo',
                  fontWeight: FontWeight.w700,
                  height: 1.30,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatBox(String text) {
    return Container(
      width: 64,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Heading3.style),
    );
  }

  Widget _buildTeamLogo(String name, String assetPath) {
    return Column(
      children: [
        SvgPicture.asset(assetPath, width: 48, height: 48),
        const SizedBox(height: 4),
        Text(name, style: Body1_b.style),
      ],
    );
  }

  Widget _buildDropdownBox({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Heading5.style),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPointsSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                selectedPoints = (selectedPoints - 100).clamp(100, 1000);
              });
            },
            child: const Icon(Icons.remove, color: Colors.white),
          ),
          Text("$selectedPoints Pts", style: Heading5.style),
          GestureDetector(
            onTap: () {
              setState(() {
                selectedPoints = (selectedPoints + 100).clamp(100, 1000);
              });
            },
            child: const Icon(Icons.add, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarChart() {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.white10,
      alignment: Alignment.center,
      child: const Text('Radar Chart Placeholder',
          style: TextStyle(color: Colors.white54)),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/barca_logo.svg',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 4),
                  Text("AAA", style: Body2.style),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('#', style: Heading3.style),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text("Sun, Sep 15",
                      style: Body2.style),
                  Text("10:15 AM", style: Body2.style,),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('#', style: Heading3.style),
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/girona_logo.svg',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(height: 4),
                  Text("BBB", style: Body2.style),
                ],
              ),
            ],
          ),
        ),
      ],
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

  Widget _buildH2HBox(String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(value, style: Heading4.style),
    );
  }
}
