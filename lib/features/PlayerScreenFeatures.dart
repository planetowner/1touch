// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/models/player.dart';

// 1. FavoritePlayersSection

class FavoritePlayersSection extends StatelessWidget {
  const FavoritePlayersSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: playerRepository.followedPlayerIds,
      builder: (context, _) {
        final players = playerRepository.favorites;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    "FAVORITE PLAYERS",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const EditFollowingPlayersSheet(),
                    );
                  },
                  icon: Icon(
                    Icons.border_color,
                    size: 24,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 148,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  return GestureDetector(
                    onTap: () => context.push('/players/${player.id}'),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 82,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                SizedBox(
                                  width: 74,
                                  height: 74,
                                  child: ClipOval(
                                      child: PlayerImage(player: player)),
                                ),
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: Container(
                                    key: const ValueKey(
                                      'favorite-player-number-badge',
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? AppPalette.lightGrey
                                          : AppPalette.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${player.jerseyNumber}',
                                      style: Body2_b.style.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              player.fullName,
                              style: Body1.style,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// 2. PlayerRankingBox + FullRankingPopup

class PlayerRankingBox extends StatefulWidget {
  final List<Player> players;

  const PlayerRankingBox({super.key, required this.players});

  @override
  State<PlayerRankingBox> createState() => _PlayerRankingBoxState();
}

class _PlayerRankingBoxState extends State<PlayerRankingBox> {
  @override
  Widget build(BuildContext context) {
    final visibleCount = widget.players.length < 5 ? widget.players.length : 5;
    final appColors = AppColors.of(context);

    return Container(
      key: const ValueKey('players-ranking-card'),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? const [
                BoxShadow(
                  color: Color(0x1F000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text("${i + 1}", style: Heading3.style),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: ClipOval(
                      child: PlayerImage(player: widget.players[i]),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.players[i].fullName, style: Heading5.style),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.players[i].teamName} • #${widget.players[i].jerseyNumber}',
                          style: Body2.style,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    widget.players[i].rankingScore.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: Heading5.style,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor:
                    isDark ? AppPalette.darkGrey : AppPalette.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const FractionallySizedBox(
                  heightFactor: 0.85,
                  child: FullRankingPopup(),
                ),
              );
            },
            child: Text("See All", style: Body2.style),
          ),
        ],
      ),
    );
  }
}

class FullRankingPopup extends StatelessWidget {
  const FullRankingPopup({super.key});

  @override
  Widget build(BuildContext context) {
    final players = playerRepository.ranking;
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      key: const ValueKey('full-ranking-sheet'),
      backgroundColor: appColors.cardBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      "1Touch Ranking",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Heading5.style.copyWith(color: colors.onSurface),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: colors.onSurface),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: appColors.subtleBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Look for players",
                          hintStyle: Body1.style.copyWith(
                            color: appColors.mutedForeground,
                          ),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: colors.onSurface),
                      ),
                    ),
                    Icon(Icons.search, color: colors.onSurface),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final player = players[index];
                  final showStar = playerRepository.isFollowing(player.id);
                  final showArrow = player.rankingChange != 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text("$rank", style: Heading4.style),
                        const SizedBox(width: 8),
                        if (showArrow)
                          const Icon(Icons.arrow_drop_up,
                              color: Colors.blueAccent)
                        else
                          const SizedBox(width: 24),
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: ClipOval(child: PlayerImage(player: player)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(player.fullName, style: Heading5.style),
                              const SizedBox(height: 2),
                              Text(
                                '${player.teamName} • #${player.jerseyNumber}',
                                style: Body2.style,
                              ),
                            ],
                          ),
                        ),
                        if (showStar) Icon(Icons.star, color: colors.onSurface),
                        Text(
                          player.rankingScore.toStringAsFixed(1),
                          style: Heading5.style,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3. OnesToWatchCard

class OnesToWatchCard extends StatelessWidget {
  final Player player;

  const OnesToWatchCard({
    super.key,
    required this.player,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 150,
      height: 200,
      margin: const EdgeInsets.only(right: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    key: const ValueKey('ones-to-watch-image-surface'),
                    width: double.infinity,
                    color: isDark
                        ? AppPalette.darkGrey
                        : appColors.subtleBackground,
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: SizedBox(
                      width: 88,
                      child: PlayerImage(player: player),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#${player.jerseyNumber}', style: Heading2.style),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              player.rankingChange < 0
                                  ? Icons.arrow_drop_down
                                  : Icons.arrow_drop_up,
                              color: const Color(0xFFE8003D),
                              size: 24,
                            ),
                            Text(
                              '${player.rankingChange.abs()}',
                              style: Body2_b.style.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              key: const ValueKey('ones-to-watch-info-surface'),
              width: double.infinity,
              color: isDark ? AppPalette.lightGrey : AppPalette.white,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Body1_b.style.copyWith(color: colors.onSurface),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${player.teamName} • ${player.jerseyNumber}',
                    style: Eyebrow.style.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 4. FilterSheet + FilterPill

class FilterSheet extends StatefulWidget {
  final String initialLeague;
  final String initialSeason;
  final String initialPosition;
  final List<String> leagues;
  final List<String> seasons;
  final List<String> positions;
  final void Function(String league, String season, String position) onApply;

  const FilterSheet({
    super.key,
    required this.initialLeague,
    required this.initialSeason,
    required this.initialPosition,
    required this.leagues,
    required this.seasons,
    required this.positions,
    required this.onApply,
  });

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late String _tempLeague;
  late String _tempSeason;
  late String _tempPosition;

  @override
  void initState() {
    super.initState();
    _tempLeague = widget.initialLeague;
    _tempSeason = widget.initialSeason;
    _tempPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? AppPalette.lightGrey : appColors.divider;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        "FILTER",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Heading5.style,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, color: colors.onSurface),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // LEAGUE
                Text("LEAGUE", style: Body2_b.style),
                const SizedBox(height: 16),
                ...List.generate(widget.leagues.length, (index) {
                  final league = widget.leagues[index];
                  final isSelected = _tempLeague == league;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          league.toUpperCase(),
                          style: Body1.style,
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: colors.onSurface)
                            : null,
                        onTap: () => setState(() => _tempLeague = league),
                      ),
                      if (index != widget.leagues.length - 1)
                        Container(height: 1, color: dividerColor),
                    ],
                  );
                }),

                const SizedBox(height: 48),

                // SEASON
                Text("SEASON", style: Body2_b.style),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {},
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _tempSeason.toUpperCase(),
                            style: Body1.style,
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.expand_more, color: colors.onSurface),
                        ],
                      ),
                      Icon(Icons.check, color: colors.onSurface),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: dividerColor),

                // POSITION
                const SizedBox(height: 48),
                Text("POSITION", style: Body2_b.style),
                const SizedBox(height: 16),
                ...List.generate(widget.positions.length, (index) {
                  final position = widget.positions[index];
                  final isSelected = _tempPosition == position;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          position.toUpperCase(),
                          style: Body1.style,
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check, color: colors.onSurface)
                            : null,
                        onTap: () => setState(() => _tempPosition = position),
                      ),
                      if (index != widget.positions.length - 1)
                        Container(height: 1, color: dividerColor),
                    ],
                  );
                }),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),

        // UPDATE FILTER button
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_tempLeague, _tempSeason, _tempPosition);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.onSurface,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("UPDATE FILTER",
                  style: Body2_b.style.copyWith(color: colors.onPrimary)),
            ),
          ),
        ),
      ],
    );
  }
}

class FilterPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const FilterPill({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: ValueKey('players-filter-pill-$label'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: Body2_b.style.copyWith(color: colors.onSurface),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 24,
              color: colors.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}

// 5. EditFollowingPlayersSheet

class EditFollowingPlayersSheet extends StatefulWidget {
  const EditFollowingPlayersSheet({super.key});

  @override
  State<EditFollowingPlayersSheet> createState() =>
      _EditFollowingPlayersSheetState();
}

class _EditFollowingPlayersSheetState extends State<EditFollowingPlayersSheet> {
  final TextEditingController _searchController = TextEditingController();

  late List<Player> _followedPlayers;
  List<Player> _filteredPlayers = [];

  bool _isSearching = false;
  String? _selectedPlayerId;
  bool _updateEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _followedPlayers = playerRepository.favorites.toList();

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _filteredPlayers = playerRepository.search(query);
        });
      } else {
        setState(() {
          _isSearching = false;
          _selectedPlayerId = null;
          _updateEnabled = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isFollowed(String id) =>
      _followedPlayers.any((player) => player.id == id);

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final selectedId = _selectedPlayerId;
    if (selectedId != null && !_isFollowed(selectedId)) {
      final player = playerRepository.findById(selectedId);
      if (player != null) _followedPlayers.add(player);
    }
    await playerRepository.updateFollowing(
      _followedPlayers.map((player) => player.id),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          key: const ValueKey('following-players-sheet'),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      "Following Players",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Heading5.style.copyWith(color: colors.onSurface),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                key: const ValueKey('following-players-search'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style.copyWith(color: colors.onSurface),
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search players to add!",
                    hintStyle: Body1.style.copyWith(
                      color: appColors.mutedForeground,
                    ),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colors.onSurface,
                              size: 20,
                            ),
                            onPressed: () => _searchController.clear(),
                          )
                        : Icon(
                            Icons.search,
                            color: colors.onSurface,
                            size: 24,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _isSearching
                    ? _buildSearchResultList(scrollController)
                    : _buildFollowedPlayerList(scrollController),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _updateEnabled && !_isSaving ? _saveChanges : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.disabled)
                              ? (isDark
                                  ? Colors.grey.shade700
                                  : const Color(0xFFC8C8C8))
                              : colors.onSurface),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>(
                          (states) => states.contains(WidgetState.disabled)
                              ? (isDark
                                  ? Colors.grey.shade400
                                  : AppPalette.white)
                              : colors.onPrimary),
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 16)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.onPrimary,
                            ),
                          )
                        : Text("UPDATE",
                            style: Body2_b.style.copyWith(
                              color: _updateEnabled
                                  ? colors.onPrimary
                                  : (isDark
                                      ? Colors.grey.shade400
                                      : AppPalette.white),
                            )),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowedPlayerList(ScrollController controller) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      controller: controller,
      itemCount: _followedPlayers.length,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? AppPalette.lightGrey : appColors.divider,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final player = _followedPlayers[index];
        final isPrimary = index == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _followedPlayers.removeAt(index);
                    _updateEnabled = true;
                  });
                },
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFF54E5C),
                  radius: 10,
                  child: Icon(Icons.remove, size: 16, color: Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(child: PlayerImage(player: player)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            player.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Heading5.style.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                        if (isPrimary)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.star,
                              color: colors.onSurface,
                              size: 18,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${player.teamName} #${player.jerseyNumber}',
                      style: Body2.style,
                    ),
                  ],
                ),
              ),
              Icon(Icons.drag_handle, color: colors.onSurface, size: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      controller: controller,
      itemCount: _filteredPlayers.length,
      separatorBuilder: (_, __) => Divider(
        color: isDark ? AppPalette.lightGrey : appColors.divider,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final player = _filteredPlayers[index];
        final isSelected = _selectedPlayerId == player.id;
        final alreadyFollowed = _isFollowed(player.id);

        return Opacity(
          opacity: alreadyFollowed ? 0.4 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(child: PlayerImage(player: player)),
              ),
              title: Text(player.fullName, style: Heading5.style),
              subtitle: Text(
                '${player.teamName} #${player.jerseyNumber}',
                style: Body2.style,
              ),
              trailing: GestureDetector(
                onTap: alreadyFollowed
                    ? null
                    : () {
                        setState(() {
                          _selectedPlayerId = player.id;
                          _updateEnabled = true;
                        });
                      },
                child: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
