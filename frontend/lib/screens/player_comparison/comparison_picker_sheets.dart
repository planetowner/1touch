part of 'player_comparison_screen.dart';

class _ComparisonPlayerPickerSheet extends StatefulWidget {
  const _ComparisonPlayerPickerSheet({
    required this.slot,
    required this.repository,
    this.excludedId,
    this.requiredPosition,
  });

  final int slot;
  final PlayerDetailRepository repository;
  final int? excludedId;
  final String? requiredPosition;

  @override
  State<_ComparisonPlayerPickerSheet> createState() =>
      _ComparisonPlayerPickerSheetState();
}

class _ComparisonPlayerPickerSheetState
    extends State<_ComparisonPlayerPickerSheet> {
  static const _searchDebounceDuration = Duration(milliseconds: 300);

  final _query = TextEditingController();
  Timer? _searchDebounce;
  late Future<List<PlayerDetail>> _players;

  @override
  void initState() {
    super.initState();
    _players = _search();
  }

  Future<List<PlayerDetail>> _search() async {
    final candidates = await widget.repository.search(_query.text.trim());
    final details = await Future.wait(
      candidates
          .where((candidate) => candidate.id != widget.excludedId)
          .take(20)
          .map((candidate) async {
        try {
          return await widget.repository.load(candidate.id);
        } on Object {
          return null;
        }
      }),
    );
    return details
        .whereType<PlayerDetail>()
        .where((player) =>
            widget.requiredPosition == null ||
            player.analysis?.position == widget.requiredPosition)
        .toList();
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, _submitSearch);
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    setState(() {
      _players = _search();
    });
  }

  void _clearSearch() {
    _query.clear();
    _submitSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final sheetSurface = isDark ? AppPalette.darkGrey : AppPalette.white;
    final fieldSurface =
        isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox;

    return DraggableScrollableSheet(
      initialChildSize: .78,
      minChildSize: .55,
      maxChildSize: .92,
      builder: (_, controller) => Material(
        key: const ValueKey('comparison-player-picker-sheet'),
        color: sheetSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      tr(context, 'Select Player {slot}',
                          {'slot': widget.slot}),
                      style: TextStyle(
                        color: foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: foreground, size: 28),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                key: const ValueKey('comparison-player-search-field'),
                controller: _query,
                autofocus: true,
                onChanged: _scheduleSearch,
                onSubmitted: (_) => _submitSearch(),
                style: TextStyle(color: foreground, fontSize: 17),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: fieldSurface,
                  hintText: tr(context, 'Search players...'),
                  hintStyle: TextStyle(color: appColors.mutedForeground),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _query,
                    builder: (_, value, __) => value.text.isEmpty
                        ? IconButton(
                            onPressed: _submitSearch,
                            icon: Icon(
                              Icons.search,
                              color: appColors.mutedForeground,
                            ),
                          )
                        : IconButton(
                            onPressed: _clearSearch,
                            icon: Icon(Icons.close, color: foreground),
                          ),
                  ),
                ),
              ),
            ),
            if (widget.requiredPosition != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: foreground, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(context,
                            'You can only pick players who play the same position.'),
                        style: TextStyle(color: foreground, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: FutureBuilder<List<PlayerDetail>>(
                future: _players,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: TextButton(
                        onPressed: _submitSearch,
                        child: Text(tr(context, 'Retry')),
                      ),
                    );
                  }
                  final players = snapshot.data ?? const [];
                  if (players.isEmpty) {
                    return Center(child: Text(tr(context, 'No players found')));
                  }
                  return ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    itemCount: players.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: appColors.divider, height: 1),
                    itemBuilder: (_, index) =>
                        _playerTile(context, players[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerTile(BuildContext context, PlayerDetail player) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final team = player.profile.teamName ?? 'Team unavailable';
    final number = player.profile.jerseyNumber;
    final subtitle = number == null ? team : '$team • #$number';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context, player),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              ClipOval(
                child: ColoredBox(
                  color: AppColors.of(context).subtleBackground,
                  child: PlayerRemoteImage(player.profile.image, size: 56),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: foreground, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonSeasonPickerSheet extends StatelessWidget {
  const _ComparisonSeasonPickerSheet({required this.player});
  final PlayerDetail player;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final surface = isDark ? AppPalette.darkGrey : AppPalette.white;
    final groups = _seasonGroups(player);

    return DraggableScrollableSheet(
      initialChildSize: .76,
      minChildSize: .5,
      maxChildSize: .92,
      builder: (_, controller) => Material(
        key: const ValueKey('comparison-season-picker-sheet'),
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 26),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: Text(
                      player.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: foreground, size: 28),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                itemCount: groups.length,
                separatorBuilder: (_, __) =>
                    Divider(color: appColors.divider, height: 32),
                itemBuilder: (_, index) => _seasonGroup(context, groups[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _seasonGroup(BuildContext context, _SeasonGroup group) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (group.image != null)
              PlayerRemoteImage(group.image, size: 40)
            else
              const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.shield_outlined),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                group.team.toUpperCase(),
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final season in group.seasons)
              Material(
                color: const Color(0xFF0A0A0A),
                borderRadius: BorderRadius.circular(6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => Navigator.pop(context, season.id),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: Text(
                      _shortSeason(season.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SeasonGroup {
  const _SeasonGroup({
    required this.team,
    required this.image,
    required this.seasons,
  });

  final String team;
  final String? image;
  final List<PlayerDetailSeason> seasons;
}

List<_SeasonGroup> _seasonGroups(PlayerDetail player) {
  final groups = <_SeasonGroup>[];
  final assigned = <int>{};

  for (final club in player.clubs) {
    final seasons = player.seasons.where((season) {
      final year = int.tryParse(season.name.split('/').first);
      if (year == null) return false;
      final midpoint = DateTime(year + 1, 1, 1);
      final afterStart =
          club.startDate == null || !midpoint.isBefore(club.startDate!);
      final beforeEnd =
          club.endDate == null || midpoint.isBefore(club.endDate!);
      return afterStart && beforeEnd;
    }).toList();
    if (seasons.isEmpty) continue;
    assigned.addAll(seasons.map((season) => season.id));
    groups.add(
      _SeasonGroup(
        team: club.teamName ?? 'Team unavailable',
        image: club.teamImage,
        seasons: seasons,
      ),
    );
  }

  final unassigned =
      player.seasons.where((season) => !assigned.contains(season.id)).toList();
  if (unassigned.isNotEmpty || groups.isEmpty) {
    groups.add(
      _SeasonGroup(
        team: player.profile.teamName ?? 'Team unavailable',
        image: player.profile.teamImage,
        seasons: unassigned.isEmpty ? player.seasons : unassigned,
      ),
    );
  }
  return groups;
}

String _shortSeason(String season) {
  final parts = season.split('/');
  if (parts.length != 2) return season;
  String shorten(String value) =>
      value.length == 4 ? value.substring(2) : value;
  return '${shorten(parts[0])}/${shorten(parts[1])}';
}
