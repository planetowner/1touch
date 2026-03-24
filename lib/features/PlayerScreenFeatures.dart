import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

// 1. FavoritePlayersSection

class FavoritePlayersSection extends StatelessWidget {
  const FavoritePlayersSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Text("FAVORITE PLAYERS", style: Body2_b.style),
            const Spacer(),
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const EditFollowingPlayersSheet(),
                );
              },
              icon: const Icon(Icons.border_color, size: 24, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 148,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => context.push('/players/son'),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            const CircleAvatar(
                              radius: 37,
                              backgroundImage: AssetImage('assets/HeungminSon.png'),
                              backgroundColor: Color(0xFF272828),
                            ),
                            Positioned(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF3D3D3D),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text("7", style: Body2_b.style),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Heungmin Son".replaceAll(' ', '\n'),
                          style: Body1.style,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        const CircleAvatar(
                          radius: 37,
                          backgroundImage: AssetImage('assets/playerAvatar.png'),
                          backgroundColor: Color(0xFF272828),
                        ),
                        Positioned(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3D3D3D),
                              shape: BoxShape.circle,
                            ),
                            child: const Text("##", style: Body2_b.style),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Player Name".replaceAll(' ', '\n'),
                      style: Body1.style,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// 2. PlayerRankingBox + FullRankingPopup

class PlayerRankingBox extends StatefulWidget {
  final List<String> players;

  const PlayerRankingBox({super.key, required this.players});

  @override
  State<PlayerRankingBox> createState() => _PlayerRankingBoxState();
}

class _PlayerRankingBoxState extends State<PlayerRankingBox> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final visibleCount = _showAll ? widget.players.length : 5;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
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
                  const CircleAvatar(
                    radius: 28,
                    backgroundImage: AssetImage('assets/playerAvatar.png'),
                    backgroundColor: Color(0xFF272828),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.players[i], style: Heading5.style),
                      const SizedBox(height: 4),
                      const Text("Team Name • ##", style: Body2.style),
                    ],
                  ),
                  SizedBox(
                    width: 80,
                    child: Text('99.7', textAlign: TextAlign.right, style: Heading5.style),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF1E1E1E),
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
    return Scaffold(
      backgroundColor: const Color(0xFF272828),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const Text("1Touch Ranking", style: Heading5.style),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Look for players",
                          hintStyle: Body1.style.copyWith(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const Icon(Icons.search, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 20,
                itemBuilder: (context, index) {
                  final rank      = index + 1;
                  final showStar  = rank == 2 || rank == 6;
                  final showArrow = rank == 1 || rank == 4 || rank == 6;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Text("$rank", style: Heading4.style),
                        const SizedBox(width: 8),
                        if (showArrow)
                          const Icon(Icons.arrow_drop_up, color: Colors.blueAccent)
                        else
                          const SizedBox(width: 24),
                        const CircleAvatar(
                          radius: 28,
                          backgroundImage: AssetImage('assets/playerAvatar.png'),
                          backgroundColor: Color(0xFF272828),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("Player Name", style: Heading5.style),
                              SizedBox(height: 2),
                              Text("Team Name • ##", style: Body2.style),
                            ],
                          ),
                        ),
                        if (!showArrow && showStar)
                          const Icon(Icons.star, color: Colors.white),
                        Text(
                          (99.7 - index * 0.3).toStringAsFixed(1),
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
  final String playerName;
  final String teamName;
  final int shirtNumber;
  final String imageUrl;
  final int rankChange;

  const OnesToWatchCard({
    super.key,
    required this.playerName,
    required this.teamName,
    required this.shirtNumber,
    required this.imageUrl,
    this.rankChange = -1,
  });

  @override
  Widget build(BuildContext context) {
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
                  Container(width: double.infinity, color: const Color(0xFF272828)),
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/HeungminSon.png',
                        fit: BoxFit.cover,
                        width: 88,
                      ),
                    )
                        : Image.asset(
                      'assets/HeungminSon.png',
                      fit: BoxFit.cover,
                      width: 88,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$shirtNumber', style: Heading2.style),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              rankChange <= 0 ? Icons.arrow_drop_down : Icons.arrow_drop_up,
                              color: const Color(0xFFE8003D),
                              size: 24,
                            ),
                            Text('${rankChange.abs()}', style: Body2_b.style),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF3D3D3D),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    playerName.replaceAll(' ', '\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Body1_b.style,
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 4),
                  Text('$teamName • $shirtNumber', style: Eyebrow.style),
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
    _tempLeague   = widget.initialLeague;
    _tempSeason   = widget.initialSeason;
    _tempPosition = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(width: 32),
                    Text("Filter", style: Heading5.style),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // LEAGUE
                Text("LEAGUE", style: Body2_b.style),
                const SizedBox(height: 16),
                ...List.generate(widget.leagues.length, (index) {
                  final league     = widget.leagues[index];
                  final isSelected = _tempLeague == league;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(league, style: Body1.style),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                        onTap: () => setState(() => _tempLeague = league),
                      ),
                      if (index != widget.leagues.length - 1)
                        Container(height: 1, color: const Color(0xFF3D3D3D)),
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
                          Text(_tempSeason, style: Body1.style),
                          const SizedBox(width: 8),
                          const Icon(Icons.expand_more, color: Colors.white),
                        ],
                      ),
                      const Icon(Icons.check, color: Colors.white),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(color: Color(0xFF3D3D3D)),

                // POSITION
                const SizedBox(height: 48),
                Text("POSITION", style: Body2_b.style),
                const SizedBox(height: 16),
                ...List.generate(widget.positions.length, (index) {
                  final position   = widget.positions[index];
                  final isSelected = _tempPosition == position;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(position, style: Body1.style),
                        trailing: isSelected ? const Icon(Icons.check, color: Colors.white) : null,
                        onTap: () => setState(() => _tempPosition = position),
                      ),
                      if (index != widget.positions.length - 1)
                        Container(height: 1, color: const Color(0xFF3D3D3D)),
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
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("UPDATE FILTER", style: Body2_b.style.copyWith(color: Colors.black)),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF3D3D3D),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: Body2_b.style),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.white),
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
  State<EditFollowingPlayersSheet> createState() => _EditFollowingPlayersSheetState();
}

class _EditFollowingPlayersSheetState extends State<EditFollowingPlayersSheet> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _allPlayers = [
    {"name": "Heungmin Son",      "team": "Tottenham",   "number": 7,  "imageUrl": null},
    {"name": "Erling Haaland",    "team": "Man City",    "number": 9,  "imageUrl": null},
    {"name": "Eduardo Camavinga", "team": "Real Madrid", "number": 6,  "imageUrl": null},
    {"name": "Éder Militao",      "team": "Real Madrid", "number": 3,  "imageUrl": null},
    {"name": "Hugo Ekitike",      "team": "Liverpool",   "number": 22, "imageUrl": null},
    {"name": "Enzo Fernández",    "team": "Chelsea",     "number": 8,  "imageUrl": null},
  ];

  late List<Map<String, dynamic>> _followedPlayers;
  List<Map<String, dynamic>> _filteredPlayers = [];

  bool _isSearching = false;
  String? _selectedPlayerName;
  bool _updateEnabled = false;

  @override
  void initState() {
    super.initState();
    _followedPlayers = _allPlayers.take(4).toList();

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        setState(() {
          _isSearching = true;
          _filteredPlayers = _allPlayers
              .where((p) => (p['name'] as String).toLowerCase().contains(query))
              .toList();
        });
      } else {
        setState(() {
          _isSearching      = false;
          _selectedPlayerName = null;
          _updateEnabled    = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isFollowed(String name) =>
      _followedPlayers.any((p) => p['name'] == name);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF272828),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const Text("Following Players", style: Heading5.style),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search players to add!",
                    hintStyle: Body1.style.copyWith(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      onPressed: () => _searchController.clear(),
                    )
                        : const Icon(Icons.search, color: Colors.white, size: 24),
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
                    onPressed: _updateEnabled ? () => Navigator.of(context).pop() : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                      states.contains(WidgetState.disabled) ? Colors.grey.shade700 : Colors.white),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                      states.contains(WidgetState.disabled) ? Colors.grey.shade400 : Colors.black),
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    child: Text("UPDATE", style: Body2_b.style.copyWith(color: Colors.black)),
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
    return ListView.separated(
      controller: controller,
      itemCount: _followedPlayers.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF3D3D3D), height: 1),
      itemBuilder: (context, index) {
        final player    = _followedPlayers[index];
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
              CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                backgroundImage: player['imageUrl'] != null
                    ? NetworkImage(player['imageUrl'] as String)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(player['name'] as String, style: Heading5.style),
                        if (isPrimary)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.star, color: Colors.white, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text("${player['team']} #${player['number']}", style: Body2.style),
                  ],
                ),
              ),
              const Icon(Icons.drag_handle, color: Colors.white, size: 28),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    return ListView.separated(
      controller: controller,
      itemCount: _filteredPlayers.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF3D3D3D), height: 1),
      itemBuilder: (context, index) {
        final player          = _filteredPlayers[index];
        final isSelected      = _selectedPlayerName == player['name'];
        final alreadyFollowed = _isFollowed(player['name'] as String);

        return Opacity(
          opacity: alreadyFollowed ? 0.4 : 1.0,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.white24,
                backgroundImage: player['imageUrl'] != null
                    ? NetworkImage(player['imageUrl'] as String)
                    : null,
              ),
              title: Text(player['name'] as String, style: Heading5.style),
              subtitle: Text("${player['team']} #${player['number']}", style: Body2.style),
              trailing: GestureDetector(
                onTap: alreadyFollowed
                    ? null
                    : () {
                  setState(() {
                    _selectedPlayerName = player['name'] as String;
                    _updateEnabled = true;
                  });
                },
                child: Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}