import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/models/player.dart';

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
  String? _selectedPlayerId;
  bool _isSearching = false;
  bool _updateEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _followedPlayers = playerRepository.favorites.toList();
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
        _filteredPlayers = playerRepository.search(query);
        _selectedPlayerId = null;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final selectedId = _selectedPlayerId;
    if (selectedId != null &&
        !_followedPlayers.any((player) => player.id == selectedId)) {
      final selectedPlayer = playerRepository.findById(selectedId);
      if (selectedPlayer != null) _followedPlayers.add(selectedPlayer);
    }

    await playerRepository.updateFollowing(
      _followedPlayers.map((player) => player.id),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          key: const ValueKey('profile-player-edit-sheet'),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      "Following Players",
                      style: Heading5.style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              Container(
                key: const ValueKey('profile-player-edit-search'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppPalette.lightGrey
                      : appColors.subtleBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  cursorColor: colors.onSurface,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search players to add!",
                    hintStyle:
                        Body1.style.copyWith(color: appColors.mutedForeground),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colors.onSurface,
                              size: 20,
                            ),
                            onPressed: _searchController.clear,
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
                  onPressed: _updateEnabled && !_isSaving ? _saveChanges : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? appColors.subtleBackground
                          : colors.onSurface,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? appColors.mutedForeground
                          : colors.onPrimary,
                    ),
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
                      : Text(
                          "UPDATE",
                          style:
                              Body2_b.style.copyWith(color: colors.onPrimary),
                        ),
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
          key: ValueKey(player.id),
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
              SizedBox(
                width: 52,
                height: 52,
                child: ClipOval(child: PlayerImage(player: player)),
              ),
              const SizedBox(width: 16),
              // Name + team
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      style: Heading5.style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${player.teamName} · #${player.jerseyNumber}',
                      style: Eyebrow.style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 32,
                ),
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
          style: Body1.style.copyWith(
            color: AppColors.of(context).mutedForeground,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _filteredPlayers.length,
      separatorBuilder: (_, __) => Divider(
        color: AppColors.of(context).divider,
        thickness: 1,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final player = _filteredPlayers[index];
        final isSelected = _selectedPlayerId == player.id;
        final alreadyFollowed =
            _followedPlayers.any((entry) => entry.id == player.id);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 52,
            height: 52,
            child: ClipOval(child: PlayerImage(player: player)),
          ),
          title: Text(
            player.fullName,
            style: Heading5.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${player.teamName} · #${player.jerseyNumber}',
            style: Eyebrow.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: GestureDetector(
            onTap: alreadyFollowed
                ? null
                : () => setState(() {
                      _selectedPlayerId = player.id;
                      _updateEnabled = true;
                    }),
            child: Icon(
              isSelected || alreadyFollowed
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: alreadyFollowed
                  ? AppColors.of(context).mutedForeground
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}
