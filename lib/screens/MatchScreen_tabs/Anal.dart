import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key});

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  bool showFCB = true;// default view
  bool get isLive => false;


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildScoreHeader(),
          _buildMatchEvents(),
          _buildXGSection(),
          const SizedBox(height: 48),
          _buildAttackBlock(),
          const SizedBox(height: 48),
          _buildPossessionBlock(),
          const SizedBox(height: 48),
          _buildProgressionBlock(),
          const SizedBox(height: 48),
          _buildPressureBlock(),
          const SizedBox(height: 48),
          _buildDefenseBlock(),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildScoreHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _teamBlock("assets/barca_logo.svg", "Team Name"),
        const SizedBox(
          width: 20,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272828),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('#', style: Heading1.style),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF272828),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('#', style: Heading1.style),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(isLive ? "42:02" : "Final", style: Body2_b.style),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.30,
              child: Container(
                width: 24,
                height: 1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text("Venue Name", style: Body2.style),
          ],
        ),
        const SizedBox(
          width: 20,
        ),
        _teamBlock("assets/girona_logo.svg", "Team Name"),
      ],
    );
  }

  Widget _teamBlock(String logo, String name) {
    return Column(
      children: [
        SvgPicture.asset(logo, width: 72, height: 72),
        const SizedBox(height: 8),
        Text(name, style: Body1.style),
      ],
    );
  }

  Widget _buildMatchEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _eventRowLeft("Player Name", "##’"),
          const SizedBox(height: 16),
          _eventRowRight("##’", "Player Name"),
          const SizedBox(height: 16),
          _eventRowRight("##’", "Player Name"),
        ],
      ),
    );
  }

  Widget _eventRowLeft(String player, String minute) {
    return Row(
      children: [
        const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
        const SizedBox(width: 6),
        Text(player, style: Body1.style),
        const Spacer(),
        Text(minute, style: Body1.style),
      ],
    );
  }

  Widget _eventRowRight(String minute, String player) {
    return Row(
      children: [
        Text(minute, style: Body1.style),
        const Spacer(),
        Text(player, style: Body1.style),
        const SizedBox(width: 6),
        const Icon(Icons.sports_soccer, color: Colors.white, size: 20),
      ],
    );
  }

  Widget _buildXGSection() {
    return SizedBox(
      width: double.infinity,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: const Color(0xFFFF5B5B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '2.7',
                    style: Body2_b.style,
                  ),
                ],
              ),
            ),
            Text('XG', textAlign: TextAlign.center, style: Body2_b.style),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '0.6',
                    style: TextStyle(
                      color: const Color(0xFF090A0A),
                      fontSize: 14,
                      fontFamily: 'Archivo',
                      fontWeight: FontWeight.w700,
                      height: 1.30,
                    ),
                  ),
                ],
              ),
            ),
          ]),
    );
  }

  Widget _buildAttackBlock() {
    return StatefulBuilder(
      builder: (context, setState) {
        final selectedTeam = showFCB ? 'FCB' : 'GRN';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("ATTACK", style: Body2_b.style),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF272828),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Toggle button styled like your IN/OUT toggle
                    _buildTeamToggle(),
                    SizedBox(height: 24,),
                    // Shot map image
                    Image.asset(
                      selectedTeam == 'FCB'
                          ? 'assets/attack_fcb.png'
                          : 'assets/attack_grn.png',
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),

                    const SizedBox(height: 24),

                    // Stats (stats don't change — only color)
                    _buildStatRow("Shots", "10", "6", selectedTeam),
                    _buildStatRow("Shots on Target", "6", "2", selectedTeam),
                    _buildStatRow("Key Passes", "7", "3", selectedTeam),
                    _buildStatRow("Passes into Penalty Area", "25", "11", selectedTeam),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPossessionBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GRN';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("POSSESSION", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTeamToggle(), // Reuse the same toggle widget
                const SizedBox(height: 24),
                _buildStatRow("Ball Possession", "63%", "37%",selectedTeam),
                _buildStatRow("Pass Accuracy", "89%", "83%",selectedTeam),
                _buildStatRow("Touches", "690", "503",selectedTeam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressionBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GRN';
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PROGRESSION", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTeamToggle(),
                const SizedBox(height: 24),
                Image.asset(
                  showFCB
                      ? 'assets/progression_fcb.png'
                      : 'assets/progression_grn.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                _buildStatRow("Progressive Passes", "51", "27",selectedTeam),
                _buildStatRow("Carries into Final Third", "13", "5",selectedTeam),
                _buildStatRow("Crosses", "22", "9",selectedTeam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPressureBlock() {
    final selectedTeam = showFCB ? 'FCB' : 'GRN';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("PRESSURE", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTeamToggle(), // 🔄 shared toggle logic
                const SizedBox(height: 24),
                Image.asset(
                  showFCB
                      ? 'assets/pressure_fcb.png'
                      : 'assets/pressure_grn.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 24),
                _buildStatRow("Pressures", "123", "98",selectedTeam),
                _buildStatRow("Successful Pressures", "75", "56",selectedTeam),
                _buildStatRow("Blocks", "21", "17",selectedTeam),
                _buildStatRow("Clearances", "15", "19",selectedTeam),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamToggle() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showFCB = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: showFCB ? const Color(0xFF3D3D3D) : Colors.black,
                border: Border.all(color: const Color(0xFF3D3D3D)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text("FCB", style: Body2_b.style),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showFCB = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: !showFCB ? const Color(0xFF3D3D3D) : Colors.black,
                border: Border.all(color: const Color(0xFF3D3D3D)),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text("GRN", style: Body2_b.style),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String fcb, String grn, String selectedTeam) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            fcb,
            style: Heading5.style.copyWith(
              color: selectedTeam == 'FCB' ? Colors.white : Colors.grey,
            ),
          ),
          Text(label, style: Body1.style),
          Text(
            grn,
            style: Heading5.style.copyWith(
              color: selectedTeam == 'GRN' ? Colors.white : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefenseBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DEFENSE", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // GA Row
                _statBoxRow(leftValue: "2", label: "GA", rightValue: "1"),
                const SizedBox(height: 16),
                // xGA Row
                _statBoxRow(leftValue: "0.8", label: "xGA", rightValue: "2.5"),
                const SizedBox(height: 24),

                // Stat rows
                ...[
                  ["10", "6", "Tackles (Success Rate)"],
                  ["6", "2", "Interceptions"],
                  ["7", "3", "Blocks"],
                  ["7", "3", "Duels (Win Rate)"],
                  ["7", "3", "Error"],
                ].map((row) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(row[0], style: Heading5.style),
                      Text(row[2], style: Body1.style),
                      Text(row[1],
                          style: Heading5.style.copyWith(
                              color: Colors.grey)),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBoxRow({
    required String leftValue,
    required String label,
    required String rightValue,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left stat box (e.g. 2)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5B5B),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            leftValue,
            style: Heading4.style.copyWith(color: Colors.white),
          ),
        ),

        // Center label (e.g. GA)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Text(
            label,
            style: Body2_b.style,
          ),
        ),

        // Right stat box (e.g. 1)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          alignment: Alignment.topRight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            rightValue,
            style: Heading4.style.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}
