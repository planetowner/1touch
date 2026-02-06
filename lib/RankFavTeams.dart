import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/WelcomeLoadingScreen.dart';

import 'core/stylesheet_dark.dart';

class RankFavoriteTeamsScreen extends StatefulWidget {
  final List<String> selectedTeams;

  const RankFavoriteTeamsScreen({super.key, required this.selectedTeams});

  @override
  State<RankFavoriteTeamsScreen> createState() =>
      _RankFavoriteTeamsScreenState();
}

class _RankFavoriteTeamsScreenState extends State<RankFavoriteTeamsScreen> {
  late List<String> _myTeams;

  // --- DATA MAPPINGS ---
  final Map<String, List<Color>> teamGradients = {
    "FC Barcelona": [const Color(0xFFD82457), const Color(0xFF460F20)],
    "Real Madrid CF": [const Color(0xFFF1F1F1), const Color(0xFFB59B00)],
    "Atlético Madrid": [const Color(0xFFC2232A), const Color(0xFF15244C)],
    "Manchester City": [const Color(0xFF6CABDD), const Color(0xFF1C2C5B)],
    "Liverpool FC": [const Color(0xFFC8102E), const Color(0xFF00A398)],
    "Arsenal FC": [const Color(0xFFEF0107), const Color(0xFF9C824A)],
    "FC Bayern Munich": [const Color(0xFFD20000), const Color(0xFF0066B2)],
    "Borussia Dortmund": [const Color(0xFFFFEE00), const Color(0xFF000000)],
    "Inter Milan": [const Color(0xFF0033A0), const Color(0xFF000000)],
    "Juventus": [const Color(0xFFFFFFFF), const Color(0xFF000000)],
    "Paris Saint-Germain": [const Color(0xFF004170), const Color(0xFFDA291C)],
    "AS Monaco": [const Color(0xFFDA291C), const Color(0xFFFED100)],
    // Short Name Mappings
    "MAN CITY": [const Color(0xFF6CABDD), const Color(0xFF1C2C5B)],
    "PSG": [const Color(0xFF004170), const Color(0xFFDA291C)],
    "BAYERN": [const Color(0xFFD20000), const Color(0xFF0066B2)],
    "INTER": [const Color(0xFF0033A0), const Color(0xFF000000)],
    "JUVENTUS": [const Color(0xFFFFFFFF), const Color(0xFF000000)],
    "BARCELONA": [const Color(0xFFD82457), const Color(0xFF460F20)],
  };

  @override
  void initState() {
    super.initState();
    _myTeams = List.from(widget.selectedTeams);
  }

  Gradient _getGradient(String teamName) {
    if (teamGradients.containsKey(teamName)) {
      return LinearGradient(colors: teamGradients[teamName]!);
    }
    if (teamGradients.containsKey(teamName.toUpperCase())) {
      return LinearGradient(colors: teamGradients[teamName.toUpperCase()]!);
    }
    return const LinearGradient(colors: [Color(0xFF333333), Colors.black]);
  }

  // [NEW] Helper for correct English suffixes (1st, 2nd, 3rd, 4th)
  String _getRankText(int index) {
    int rank = index + 1;
    if (rank == 1) return "Most Favorite";

    String suffix = "th";
    if (rank % 100 < 11 || rank % 100 > 13) {
      switch (rank % 10) {
        case 1:
          suffix = "st";
          break;
        case 2:
          suffix = "nd";
          break;
        case 3:
          suffix = "rd";
          break;
      }
    }
    return "$rank$suffix Favorite";
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final String item = _myTeams.removeAt(oldIndex);
      _myTeams.insert(newIndex, item);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0C),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // [FIX] Left side: Back Button + Logo
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        tooltip: "Go back",
                      ),
                      const SizedBox(width: 8),
                      // Logo
                      SvgPicture.asset(
                        'assets/app_logo.svg',
                        height: 23,
                        width: 100,
                      ),
                    ],
                  ),

                  // Right side: Switch
                  Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Switch(
                        value: false,
                        onChanged: (v) {},
                        activeColor: Colors.white,
                        inactiveTrackColor: Colors.grey,
                      ),
                    ],
                  )
                ],
              ),
            ),

            // --- DRAGGABLE LIST ---
            Expanded(
              child: ReorderableListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                onReorder: _onReorder,
                // [OPTIONAL] proxyDecorator customizes the look WHILE dragging
                proxyDecorator: (child, index, animation) {
                  return AnimatedBuilder(
                    animation: animation,
                    builder: (BuildContext context, Widget? child) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 10,
                        shadowColor: Colors.black54,
                        child: Transform.scale(
                          scale: 1.05, // Slightly larger when dragging
                          child: child,
                        ),
                      );
                    },
                    child: child,
                  );
                },
                children: [
                  for (int index = 0; index < _myTeams.length; index++)
                    _buildTeamCard(index, _myTeams[index]),
                ],
              ),
            ),

            // --- BOTTOM SECTION ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text("Rank your clubs", style: Heading5.style),
                  const SizedBox(height: 8),
                  Text(
                      "Drag and drop to order your favorite clubs.\nThe one at the top will be your #1.\nDon’t worry, you can always change this later.",
                      textAlign: TextAlign.center,
                      style: Body2.style),

                  const SizedBox(height: 30),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const WelcomeLoadingScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      "CONTINUE",
                      style: Body2_b.style.copyWith(color: Colors.black),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(int index, String teamName) {
    // Distinct Design for #1 vs Others
    final isFirst = index == 0;

    return Container(
      key: ValueKey(teamName),
      // Essential for ReorderableListView
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        gradient: _getGradient(teamName),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
        // Subtle border for the top team
        border: isFirst
            ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {}, // Needed for InkWell to show ripple
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // --- LEFT BOX (Star or Number) ---
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: isFirst
                      ? const Icon(Icons.star, color: Colors.white, size: 20)
                      : Text(
                          "${index + 1}",
                          style: Heading5.style,
                        ),
                ),

                const SizedBox(width: 16),

                // --- TEAM NAME ---
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teamName,
                        style: Heading5.style,
                      ),
                      // [FIX] Correct ordinal text (1st, 2nd, 3rd...)
                      Text(
                        _getRankText(index),
                        style: Body2.style.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                // --- DRAG HANDLE ---
                // Wrapping this in ReorderableDragStartListener makes it draggable immediately!
                ReorderableDragStartListener(
                  index: index,
                  child: Container(
                    padding: const EdgeInsets.all(8.0), // Bigger touch target
                    color: Colors.transparent,
                    child: Icon(Icons.drag_handle_rounded,
                        color: Colors.white.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniLogo(String teamName) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _getGradient(teamName),
          border: Border.all(color: Colors.white, width: 2)),
      alignment: Alignment.center,
      child:
          Text(teamName.isNotEmpty ? teamName[0] : "", style: Heading5.style),
    );
  }
}
