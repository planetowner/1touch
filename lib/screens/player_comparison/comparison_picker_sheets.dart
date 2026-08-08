part of 'player_comparison_screen.dart';

class _PlayerPickerSheet extends StatefulWidget {
  final int slot;
  final String? excludedId;
  final void Function(ComparisonPlayer) onPick;

  const _PlayerPickerSheet({
    required this.slot,
    this.excludedId,
    required this.onPick,
  });

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  String _query = '';

  List<ComparisonPlayer> get _filtered => kComparisonPlayers
      .where((player) => player.id != widget.excludedId)
      .where(
        (player) =>
            player.fullName.toLowerCase().contains(_query.toLowerCase()) ||
            player.team.toLowerCase().contains(_query.toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final sheetSurface = isDark ? const Color(0xFF1C1C1E) : AppPalette.white;
    final fieldSurface =
        isDark ? const Color(0xFF2C2C2E) : AppPalette.lightGreyBox;

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        key: const ValueKey('comparison-player-picker-sheet'),
        decoration: BoxDecoration(
          color: sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    'Select Player ${widget.slot}',
                    style: TextStyle(
                      color: foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _SheetCloseButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: foreground),
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  hintStyle: TextStyle(color: appColors.mutedForeground),
                  filled: true,
                  fillColor: fieldSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _query = ''),
                          child: Icon(
                            Icons.close,
                            color: appColors.mutedForeground,
                            size: 18,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    Divider(color: appColors.divider, height: 1),
                itemBuilder: (_, index) =>
                    _buildPlayerPickerTile(player: _filtered[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerPickerTile({required ComparisonPlayer player}) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;

    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: player.teamColor.withValues(alpha: 0.18),
          child: Text(
            player.fullName.split(' ').map((part) => part[0]).take(2).join(),
            style: TextStyle(
              color: player.teamColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          player.fullName,
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${player.team} • #${player.number}',
          style: TextStyle(color: mutedForeground, fontSize: 12),
        ),
        trailing: Icon(Icons.chevron_right, color: mutedForeground),
        onTap: () => widget.onPick(player),
      ),
    );
  }
}

class _SeasonPickerSheet extends StatelessWidget {
  final ComparisonPlayer player;
  final void Function(String) onPick;

  const _SeasonPickerSheet({required this.player, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final sheetSurface = isDark ? const Color(0xFF1C1C1E) : AppPalette.white;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        key: const ValueKey('comparison-season-picker-sheet'),
        decoration: BoxDecoration(
          color: sheetSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const _SheetHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Row(
                children: [
                  const Spacer(),
                  Text(
                    player.fullName,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  _SheetCloseButton(onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: player.clubSeasons.entries
                    .map((entry) => _buildClubSeasons(context, entry))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClubSeasons(
    BuildContext context,
    MapEntry<String, List<String>> entry,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: player.teamColor.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    entry.key[0],
                    style: TextStyle(
                      color: player.teamColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.value.map((season) {
              return GestureDetector(
                onTap: () => onPick(season),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : AppPalette.lightGreyBox,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    season,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Divider(color: appColors.divider, height: 1),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 4),
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white24
            : AppColors.of(context).mutedForeground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SheetCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        Icons.close,
        color: Theme.of(context).colorScheme.onSurface,
        size: 22,
      ),
    );
  }
}
