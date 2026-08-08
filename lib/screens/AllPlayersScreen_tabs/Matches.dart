import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';

class MatchesTab extends StatefulWidget {
  final Player player;

  const MatchesTab({super.key, required this.player});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  String _selectedSeason = "CURRENT SEASON";
  final List<String> _seasons = [
    "CURRENT SEASON",
    "2025/2026",
    "2024/2025",
  ];

  List<PlayerMatchSummary> get _matches =>
      playerRepository.recentMatchesFor(widget.player.id);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('player-matches-scroll'),
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSeasonDropdown(),
          const SizedBox(height: 24),
          _buildLiveHeader(),
          const SizedBox(height: 16),
          if (_matches.isNotEmpty) _matchCard(_matches.first),
          const SizedBox(height: 20),
          Divider(color: AppColors.of(context).divider, height: 1),
          const SizedBox(height: 24),
          Text("RECENT MATCHES", style: Body2_b.style),
          const SizedBox(height: 16),
          ..._matches.skip(1).map(_matchCard),
          const SizedBox(height: 144),
        ],
      ),
    );
  }

  Widget _buildSeasonDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF3D3D3D) : AppPalette.white;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Container(
      key: const ValueKey('player-matches-season-filter'),
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSeason,
          isExpanded: true,
          dropdownColor: surface,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: foreground,
            size: 24,
          ),
          style: Body2_b.style.copyWith(color: foreground),
          onChanged: (value) {
            if (value != null) setState(() => _selectedSeason = value);
          },
          items: _seasons.map((season) {
            return DropdownMenuItem(
              value: season,
              child: Text(
                season,
                style: Body2_b.style.copyWith(color: foreground),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLiveHeader() {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: foreground,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text("LIVE", style: Body2_b.style),
      ],
    );
  }

  Widget _matchCard(PlayerMatchSummary match) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PlayerMatchCard(
        result: match.result,
        score: match.score,
        competition: match.competition,
        againstLogo: match.opponentLogoAsset,
        stats: [
          {'label': 'Goal', 'value': '${match.goals}'},
          {'label': 'Assist', 'value': '${match.assists}'},
          {'label': 'Pass', 'value': '${match.passes}'},
        ],
        rating: match.rating.toStringAsFixed(1),
      ),
    );
  }
}
