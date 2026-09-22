part of 'player_screen_features.dart';

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
        padding: AppDropdownTokens.triggerPadding,
        decoration: BoxDecoration(
          color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
          borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: Body2_b.style.copyWith(color: colors.onSurface),
            ),
            const SizedBox(width: AppDropdownTokens.gap),
            AppDropdownChevron(color: colors.onSurface),
          ],
        ),
      ),
    );
  }
}

// 5. EditFollowingPlayersSheet
