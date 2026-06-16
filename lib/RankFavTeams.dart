import 'package:flutter/material.dart';
import 'package:onetouch/WelcomeLoadingScreen.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/team.dart';

const _domesticLeagueIds = {8, 82, 301, 384, 564};

class RankFavoriteTeamsScreen extends StatefulWidget {
  final List<Team> selectedTeams;

  const RankFavoriteTeamsScreen({super.key, required this.selectedTeams});

  @override
  State<RankFavoriteTeamsScreen> createState() =>
      _RankFavoriteTeamsScreenState();
}

class _RankFavoriteTeamsScreenState extends State<RankFavoriteTeamsScreen> {
  late List<Team> _myTeams;

  @override
  void initState() {
    super.initState();
    _myTeams = List.from(widget.selectedTeams);
  }

  String _leagueSubtitle(Team team) {
    final standing = mockStandings
        .where((s) =>
            s.teamId == team.teamId && _domesticLeagueIds.contains(s.leagueId))
        .firstOrNull;
    if (standing == null) return '';
    final league =
        mockLeagues.where((l) => l.leagueId == standing.leagueId).firstOrNull;
    return '${league?.name ?? ''} ${_ordinal(standing.position)}';
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final team = _myTeams.removeAt(oldIndex);
      _myTeams.insert(newIndex, team);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: Color(0xFF000000)),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0.10, -0.00),
                end: Alignment(0.10, 1.00),
                colors: [Color(0xFF282929), Color(0x00282929)],
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new,
                            color: Colors.white),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.brightness_4,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Switch(
                            value: false,
                            onChanged: (_) {},
                            activeThumbColor: Colors.white,
                            inactiveTrackColor: Colors.white54,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Draggable list
                Expanded(
                  child: ReorderableListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    onReorder: _onReorder,
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 12,
                      shadowColor: Colors.black54,
                      child: Transform.scale(scale: 1.03, child: child),
                    ),
                    children: [
                      for (int i = 0; i < _myTeams.length; i++)
                        _buildTeamCard(i, _myTeams[i]),
                    ],
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      const Text("Rank your clubs", style: Heading4.style),
                      const SizedBox(height: 8),
                      Text(
                        "Hold and drag a team card up or down to reorder your favorites. Don't worry, you can always change this later.",
                        textAlign: TextAlign.center,
                        style: Body2.style,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WelcomeLoadingScreen()),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text("CONTINUE",
                            style: Body2_b.style.copyWith(color: Colors.black)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(int index, Team team) {
    final isFirst = index == 0;
    final primaryColor = Color(team.primaryColor);
    final darkerColor = Color.lerp(primaryColor, Colors.black, 0.55)!;
    final subtitle = _leagueSubtitle(team);

    return Container(
      key: ValueKey(team.teamId),
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Rank indicator — outside the card, left
          SizedBox(
            width: 32,
            child: Center(
              child: isFirst
                  ? const Icon(Icons.star, color: Colors.white, size: 18)
                  : Text('${index + 1}', style: Heading5.style),
            ),
          ),
          const SizedBox(width: 8),
          // Card
          Expanded(
            child: SizedBox(
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [primaryColor, darkerColor],
                  ),
                  border: isFirst
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Logo watermark — right side
                      if (team.imagePath != null)
                        Positioned(
                          right: -10,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: 0.35,
                            child: Image.network(
                              team.imagePath!,
                              width: 130,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      // Team name + league — left side
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.name, style: Heading5.style),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: Body2.style.copyWith(
                                    fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Drag handle — far right
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.transparent,
                            child: Center(
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
