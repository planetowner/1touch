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
  final _players = <PlayerComparisonCandidate>[];
  String _activeQuery = '';
  int _total = 0;
  int _request = 0;
  bool _loading = false;
  bool _failed = false;
  int? _selectingId;
  int? _failedSelectionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) {
        _players.clear();
        _total = 0;
        _failedSelectionId = null;
      }
    });
    try {
      final page = await widget.repository.comparisonCandidates(
        _activeQuery,
        position: widget.requiredPosition,
        excludedId: widget.excludedId,
        offset: _players.length,
      );
      // 검색어가 바뀌면 이전 검색이나 추가 페이지 응답을 섞지 않아요.
      if (!mounted || request != _request) return;
      setState(() {
        _players.addAll(page.players);
        _total = page.total;
      });
    } on Object {
      if (mounted && request == _request) setState(() => _failed = true);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<void> _selectPlayer(int id) async {
    _searchDebounce?.cancel();
    setState(() {
      _selectingId = id;
      _failedSelectionId = null;
    });
    try {
      // 후보마다 통계를 불러오면 DB 연결이 부족해져서 선택한 선수만 조회해요.
      final player = await widget.repository.load(id);
      // 닫히는 애니메이션 중에도 mounted라서, 이미 닫은 시트가 뒤 화면을 닫지 않게 해요.
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context, player);
      }
    } on Object {
      if (mounted) {
        setState(() {
          _selectingId = null;
          _failedSelectionId = id;
        });
      }
    }
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, _submitSearch);
  }

  void _submitSearch() {
    _searchDebounce?.cancel();
    _activeQuery = _query.text.trim();
    _load();
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
                enabled: _selectingId == null,
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
                    borderRadius:
                        BorderRadius.circular(AppSearchFieldTokens.radius),
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
            Expanded(child: _playerList(controller)),
          ],
        ),
      ),
    );
  }

  Widget _playerList(ScrollController controller) {
    if (_players.isEmpty) {
      if (_loading) return const Center(child: FootballLoadingIndicator());
      if (_failed) {
        return Center(
            child: TextButton(
          onPressed: _submitSearch,
          child: Text(tr(context, 'Retry')),
        ));
      }
      return Center(child: Text(tr(context, 'No players found')));
    }
    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: _players.length + (_players.length < _total ? 1 : 0),
      separatorBuilder: (_, __) =>
          Divider(color: AppColors.of(context).divider, height: 1),
      itemBuilder: (_, index) {
        if (index < _players.length) {
          return _playerTile(context, _players[index]);
        }
        return Center(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: FootballLoadingIndicator())
                : TextButton(
                    key: const ValueKey('comparison-load-more'),
                    onPressed:
                        _selectingId == null ? () => _load(more: true) : null,
                    child: Text(tr(context, _failed ? 'Retry' : 'Load more')),
                  ));
      },
    );
  }

  Widget _playerTile(
      BuildContext context, PlayerComparisonCandidate candidate) {
    final player = candidate.player;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final team = teamNameLabel(
        context, candidate.teamId, candidate.teamName ?? 'Team unavailable');
    final number = candidate.jerseyNumber;
    final subtitle = number == null ? team : '$team • #$number';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('comparison-candidate-${player.id}'),
        onTap: _selectingId == null ? () => _selectPlayer(player.id) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              ClipOval(
                child: ColoredBox(
                  color: AppColors.of(context).subtleBackground,
                  child: PlayerRemoteImage(player.image, size: 56),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerNameLabel(context, player.id, player.name),
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
                    if (_failedSelectionId == player.id) ...[
                      Text(
                        tr(context,
                            'Could not load player data. Please select the player again.'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                      TextButton(
                        onPressed: _selectingId == null
                            ? () => _selectPlayer(player.id)
                            : null,
                        child: Text(tr(context, 'Retry')),
                      ),
                    ],
                  ],
                ),
              ),
              if (_selectingId == player.id)
                const SizedBox(
                    width: 34, height: 34, child: FootballLoadingIndicator())
              else
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
                      playerNameLabel(
                          context, player.playerId, player.profile.name),
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
                teamNameLabel(context, group.teamId, group.team).toUpperCase(),
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
                      compactSeasonLabel(season.name),
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
    required this.teamId,
    required this.team,
    required this.image,
    required this.seasons,
  });

  final String team;
  final int? teamId;
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
        teamId: club.teamId,
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
        teamId: player.profile.teamId,
        team: player.profile.teamName ?? 'Team unavailable',
        image: player.profile.teamImage,
        seasons: unassigned.isEmpty ? player.seasons : unassigned,
      ),
    );
  }
  return groups;
}
