import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';

class EditFollowingPlayersSheet extends StatefulWidget {
  const EditFollowingPlayersSheet({super.key});

  @override
  State<EditFollowingPlayersSheet> createState() =>
      _EditFollowingPlayersSheetState();
}

class _EditFollowingPlayersSheetState extends State<EditFollowingPlayersSheet> {
  static const _currentUserId = 1001;

  final TextEditingController _searchController = TextEditingController();

  late List<MockFollowingPlayer> _followedPlayers;

  // Search pool: all unique players across all users
  final List<MockFollowingPlayer> _allPlayers = mockUserFollowingPlayers;

  List<MockFollowingPlayer> _filteredPlayers = [];
  int? _selectedPlayerId;
  bool _isSearching = false;
  bool _updateEnabled = false;

  @override
  void initState() {
    super.initState();
    _followedPlayers = followingPlayersByUser(_currentUserId).toList();
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _selectedPlayerId = null;
      });
    } else {
      setState(() {
        _isSearching = true;
        _filteredPlayers = _allPlayers
            .where((p) => p.playerName.toLowerCase().contains(query))
            .toList();
        _selectedPlayerId = null;
      });
    }
  }

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
              // Title
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

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search players to add!",
                    hintStyle: Body1.style.copyWith(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: _searchController.clear,
                          )
                        : const Icon(Icons.search,
                            color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Player list (followed or search results)
              Expanded(
                child: _isSearching
                    ? _buildSearchResultList(scrollController)
                    : _buildFollowedPlayerList(scrollController),
              ),

              const SizedBox(height: 16),

              // UPDATE button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _updateEnabled ? () => Navigator.of(context).pop() : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.grey.shade700
                          : Colors.white,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.grey.shade400
                          : Colors.black,
                    ),
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 16)),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  child: Text("UPDATE",
                      style: Body2_b.style.copyWith(color: Colors.black)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowedPlayerList(ScrollController controller) {
    return ReorderableListView.builder(
      scrollController: controller,
      itemCount: _followedPlayers.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _followedPlayers.removeAt(oldIndex);
          _followedPlayers.insert(newIndex, item);
          _updateEnabled = true;
        });
      },
      itemBuilder: (context, index) {
        final player = _followedPlayers[index];
        return Padding(
          key: ValueKey(player.playerId),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Remove button
              GestureDetector(
                onTap: () => setState(() {
                  _followedPlayers.removeAt(index);
                  _updateEnabled = true;
                }),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFF54E5C),
                  radius: 10,
                  child: Icon(Icons.remove, size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              // Avatar with jersey number badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF3D3D3D),
                    backgroundImage: player.imageUrl != null
                        ? NetworkImage(player.imageUrl!) as ImageProvider
                        : const AssetImage('assets/playerAvatar.png'),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Name + team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.playerName, style: Heading5.style),
                    const SizedBox(height: 4),
                    Text(
                      '${player.teamName} · #${player.jerseyNumber}',
                      style: Eyebrow.style,
                    ),
                  ],
                ),
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    if (_filteredPlayers.isEmpty) {
      return Center(
        child: Text(
          "No players found",
          style: Body1.style.copyWith(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _filteredPlayers.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Color(0xFF3D3D3D), thickness: 1, height: 1),
      itemBuilder: (context, index) {
        final player = _filteredPlayers[index];
        final isSelected = _selectedPlayerId == player.playerId;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFF3D3D3D),
            backgroundImage: player.imageUrl != null
                ? NetworkImage(player.imageUrl!) as ImageProvider
                : const AssetImage('assets/playerAvatar.png'),
          ),
          title: Text(player.playerName, style: Heading5.style),
          subtitle: Text(
            '${player.teamName} · #${player.jerseyNumber}',
            style: Eyebrow.style,
          ),
          trailing: GestureDetector(
            onTap: () => setState(() {
              _selectedPlayerId = player.playerId;
              _updateEnabled = true;
            }),
            child: Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}
