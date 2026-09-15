part of 'player_screen_features.dart';

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
