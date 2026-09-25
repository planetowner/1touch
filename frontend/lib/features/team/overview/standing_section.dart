part of 'team_screen_features.dart';

class Standing extends StatefulWidget {
  const Standing({
    super.key,
    this.teams,
    this.onCompetitionSelected,
    this.repository,
  });

  final teams;
  final ValueChanged<int>? onCompetitionSelected;
  final StandingRepository? repository;

  @override
  State<Standing> createState() => _StandingState();
}

class _StandingState extends State<Standing> {
  static const double _rankW = 24;
  static const double _clubToStatsGap = 16;
  static const double _statGap = 15;
  static const double _pointsW = 24;
  static const double _matchesPlayedW = 22;
  static const double _resultStatW = 18;

  List<standing_model.Standing> _standings = const [];
  bool _isLoading = false;
  Object? _loadError;
  int _requestId = 0;

  StandingRepository get _repository =>
      widget.repository ?? apiStandingRepository;

  int? get _teamId {
    if (widget.teams case final Map<String, dynamic> teams) {
      return teams['id'] as int?;
    }
    return null;
  }

  int? get _domesticCompetitionId {
    final teamId = _teamId;
    if (teamId == null) return null;
    return teamCompetitionContextResolver.resolve(teamId)?.competitionId;
  }

  @override
  void initState() {
    super.initState();
    _startLoad(updateState: false);
  }

  @override
  void didUpdateWidget(covariant Standing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTeamId = oldWidget.teams is Map<String, dynamic>
        ? (oldWidget.teams as Map<String, dynamic>)['id'] as int?
        : null;
    if (oldTeamId != _teamId || oldWidget.repository != widget.repository) {
      _startLoad();
    }
  }

  void _startLoad({bool updateState = true}) {
    final competitionId = _domesticCompetitionId;
    final requestId = ++_requestId;
    StandingRepository? repository;
    List<standing_model.Standing>? cached;
    Object? repositoryError;
    if (competitionId != null) {
      try {
        repository = _repository;
        cached = repository.cachedForCompetition(competitionId);
      } on Object catch (error) {
        repositoryError = error;
      }
    }

    void prepare() {
      _standings = cached ?? const [];
      _isLoading =
          competitionId != null && cached == null && repositoryError == null;
      _loadError = repositoryError;
    }

    if (updateState) {
      setState(prepare);
    } else {
      prepare();
    }

    if (competitionId != null && repository != null) {
      unawaited(
        _loadCurrentTable(competitionId, requestId, repository),
      );
    }
  }

  Future<void> _loadCurrentTable(
    int competitionId,
    int requestId,
    StandingRepository repository,
  ) async {
    try {
      // Deliberately omit seasonId. The backend resolves the current season,
      // so Overview cannot become stale when the season rolls over.
      final rows = await repository.loadForCompetition(competitionId);
      if (!mounted ||
          requestId != _requestId ||
          competitionId != _domesticCompetitionId) {
        return;
      }
      setState(() {
        _standings = rows;
        _isLoading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted ||
          requestId != _requestId ||
          competitionId != _domesticCompetitionId) {
        return;
      }
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTeamId = _teamId;
    final leagueId = _domesticCompetitionId;
    if (currentTeamId == null || leagueId == null) {
      return const SizedBox.shrink();
    }
    if (_isLoading && _standings.isEmpty) {
      return const Padding(
        key: ValueKey('overview-standing-loading'),
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null && _standings.isEmpty) {
      return Padding(
        key: const ValueKey('overview-standing-error'),
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: TextButton(
            key: const ValueKey('overview-standing-retry'),
            onPressed: _startLoad,
            child: Text(tr(context, 'Retry standings')),
          ),
        ),
      );
    }
    if (_standings.isEmpty) return const SizedBox.shrink();

    return _buildStandingCard(
      leagueId,
      rows: _rowsForLeague(currentTeamId),
      isFirst: true,
      isLast: true,
    );
  }

  List<Map<String, dynamic>> _rowsForLeague(int currentTeamId) {
    final allRows = _standings.map((s) {
      final repositoryTeam = teamRepository.findById(s.teamId);
      final responseName = s.teamName?.trim();
      final displayName = teamNameLabel(
        context,
        s.teamId,
        (responseName?.isNotEmpty ?? false ? responseName! : null) ??
            repositoryTeam?.name ??
            'Unknown Team',
      );
      return {
        'rank': s.position,
        'team': displayName,
        'pts': s.points.toString(),
        'mp': s.matchesPlayed.toString(),
        'w': s.won.toString(),
        'd': s.draw.toString(),
        'l': s.lost.toString(),
        'hl': s.teamId == currentTeamId,
      };
    }).toList();

    final currentIndex = allRows.indexWhere((r) => r['hl'] == true);
    const windowSize = 5;
    if (currentIndex == -1) return allRows.take(windowSize).toList();

    // Keep the top five fixed while the selected team is ranked 1st–5th.
    // Below that, center the team between two rows on either side whenever
    // possible, shifting the final window upward near the bottom of the table.
    final maxStart =
        allRows.length > windowSize ? allRows.length - windowSize : 0;
    var start = currentIndex < windowSize ? 0 : currentIndex - 2;
    start = start.clamp(0, maxStart);
    final end = (start + windowSize).clamp(0, allRows.length);
    return allRows.sublist(start, end);
  }

  Widget _buildStandingCard(int leagueId,
      {required List<Map<String, dynamic>> rows,
      required bool isFirst,
      required bool isLast}) {
    final league = competitionRepository.findById(leagueId);
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bodyBackground =
        isLight ? AppPalette.lightGreyBox : appColors.cardBackground;
    final headerBackground =
        isLight ? AppPalette.white : appColors.subtleBackground;
    return Padding(
      padding: EdgeInsets.only(
        left: isFirst ? 24 : 0,
        right: isLast ? 24 : 16,
        top: 16,
        bottom: 16,
      ),
      child: Container(
        key: ValueKey('overview-standing-shell-$leagueId'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: appCardShadows(context),
        ),
        child: Material(
          color: bodyBackground,
          elevation: 0,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onCompetitionSelected == null
                ? null
                : () => widget.onCompetitionSelected!(leagueId),
            child: Container(
              key: ValueKey('overview-standing-card-$leagueId'),
              width: 345,
              decoration: BoxDecoration(color: bodyBackground),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header block
                  Container(
                    key: ValueKey('overview-standing-header-$leagueId'),
                    color: headerBackground,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 24,
                        ),
                        // league title line
                        Row(
                          children: [
                            Image.network(
                              league?.imagePath ?? '',
                              width: 24,
                              height: 24,
                              errorBuilder: (_, __, ___) =>
                                  competitionLogoFallback(leagueId, size: 24),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                competitionNameLabel(
                                    context,
                                    league?.competitionId,
                                    league?.name ?? tr(context, 'Unknown')),
                                style: Heading4.style,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // columns header line (uses same table grid as body)
                        _columnsHeader(),
                        SizedBox(
                          height: 12,
                        ),
                      ],
                    ),
                  ),
                  // body rows table (aligned with header)
                  Padding(
                    key: ValueKey('overview-standing-body-$leagueId'),
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: _rowsTable(rows),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // shared columnWidths for perfect alignment
  Map<int, TableColumnWidth> get _grid => const {
        0: FixedColumnWidth(_rankW), // #
        1: FlexColumnWidth(), // Club
        2: FixedColumnWidth(_clubToStatsGap), // Club → Pts
        3: FixedColumnWidth(_pointsW), // Pts
        4: FixedColumnWidth(_statGap), // Pts → MP
        5: FixedColumnWidth(_matchesPlayedW), // MP
        6: FixedColumnWidth(_statGap), // MP → W
        7: FixedColumnWidth(_resultStatW), // W
        8: FixedColumnWidth(_statGap), // W → D
        9: FixedColumnWidth(_resultStatW), // D
        10: FixedColumnWidth(_statGap), // D → L
        11: FixedColumnWidth(_resultStatW), // L
      };

  Widget _columnsHeader() {
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            Text("#",
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            Text(tr(context, "Club"),
                key: const ValueKey('overview-standing-club-header'),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-points-header'),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(tr(context, "Pts"),
                      maxLines: 1,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface)),
                )),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-mp-header'),
                alignment: Alignment.center,
                child: Text(tr(context, "MP"),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-win-header'),
                alignment: Alignment.center,
                child: Text(tr(context, "W"),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-draw-header'),
                alignment: Alignment.center,
                child: Text(tr(context, "D"),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-loss-header'),
                alignment: Alignment.center,
                child: Text(tr(context, "L"),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
          ],
        ),
      ],
    );
  }

  Widget _rowsTable(List<Map<String, dynamic>> data) {
    final colors = Theme.of(context).colorScheme;
    final muted = AppColors.of(context).mutedForeground;
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: data.indexed.map((entry) {
        final index = entry.$1;
        final r = entry.$2;
        final bool hl = r["hl"] == true;
        final Color c = hl ? colors.onSurface : muted;
        final FontWeight w = hl ? FontWeight.w700 : FontWeight.w400;
        final rowPadding = EdgeInsets.only(
          bottom: index == data.length - 1 ? 0 : 16,
        );

        return TableRow(
          children: [
            Padding(
              padding: rowPadding,
              child: Text("${r["rank"]}",
                  style: TextStyle(color: c, fontWeight: w)),
            ),
            Padding(
              padding: rowPadding,
              child: Text(
                r["team"],
                key: ValueKey('overview-standing-team-${r["rank"]}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontWeight: w),
              ),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: rowPadding,
              child: Align(
                  key: ValueKey('overview-standing-points-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["pts"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: rowPadding,
              child: Align(
                  key: ValueKey('overview-standing-mp-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["mp"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: rowPadding,
              child: Align(
                  key: ValueKey('overview-standing-win-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["w"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: rowPadding,
              child: Align(
                  key: ValueKey('overview-standing-draw-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["d"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: rowPadding,
              child: Align(
                  key: ValueKey('overview-standing-loss-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["l"], style: Heading5.style.copyWith(color: c))),
            ),
          ],
        );
      }).toList(),
    );
  }
}
