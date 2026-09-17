part of 'team_screen_features.dart';

class Standing extends StatefulWidget {
  const Standing({
    super.key,
    this.teams,
    this.onCompetitionSelected,
  });

  final teams;
  final ValueChanged<int>? onCompetitionSelected;

  @override
  _StandingState createState() => _StandingState();
}

class _StandingState extends State<Standing> {
  // grid widths (tweak if needed)
  static const double _rankW = 32;
  static const double _gapW = 16;
  static const double _statW = 28;

  @override
  Widget build(BuildContext context) {
    int? currentTeamId;
    if (widget.teams is Map<String, dynamic>) {
      currentTeamId = (widget.teams as Map<String, dynamic>)['id'] as int?;
    }
    if (currentTeamId == null) return const SizedBox.shrink();

    // Every competition this team currently has fixtures in — domestic
    // league first, then UCL/Europa if they've qualified for one. Each gets
    // its own card; swipe sideways to see the next, same as team picking.
    final domesticCompetitionIds = competitionRepository.domesticCompetitions
        .map((competition) => competition.competitionId)
        .toSet();
    final leagueIds = fixtureRepository
        .forTeam(currentTeamId)
        .map((f) => f.competitionId)
        .toSet()
        .where((id) => standingRepository.forCompetition(id).isNotEmpty)
        .toList()
      ..sort((a, b) {
        final aIsDomestic = domesticCompetitionIds.contains(a);
        final bIsDomestic = domesticCompetitionIds.contains(b);
        if (aIsDomestic != bIsDomestic) return aIsDomestic ? -1 : 1;
        return a.compareTo(b);
      });

    if (leagueIds.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < leagueIds.length; i++)
              _buildStandingCard(
                leagueIds[i],
                rows: _rowsForLeague(leagueIds[i], currentTeamId),
                isFirst: i == 0,
                isLast: i == leagueIds.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _rowsForLeague(int leagueId, int? currentTeamId) {
    final standings = standingRepository.forCompetition(leagueId);
    final allRows = standings.map((s) {
      final repositoryTeam = teamRepository.findById(s.teamId);
      final responseName = s.teamName?.trim();
      final displayName = repositoryTeam?.shortCode ??
          (responseName?.isNotEmpty ?? false ? responseName! : null) ??
          repositoryTeam?.name ??
          'Unknown Team';
      return {
        'rank': s.position,
        'team': displayName,
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
      child: Material(
        color: bodyBackground,
        elevation: 5,
        borderRadius: BorderRadius.circular(20),
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              league?.name ?? 'Unknown',
                              style: Heading4.style,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // columns header line (uses same table grid as body)
                      _columnsHeader(),
                      SizedBox(
                        height: 12,
                      ),
                    ],
                  ),
                ),
                // divider
                Container(height: 1, color: appColors.divider),

                // body rows table (aligned with header)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: _rowsTable(rows),
                ),
              ],
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
        2: FixedColumnWidth(_gapW), // Club → MP
        3: FixedColumnWidth(_statW), // MP
        4: FixedColumnWidth(_gapW), // MP → W
        5: FixedColumnWidth(_statW), // W
        6: FixedColumnWidth(_gapW), // W → D
        7: FixedColumnWidth(_statW), // D
        8: FixedColumnWidth(_gapW), // D → L
        9: FixedColumnWidth(_statW), // L
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
            Text("Club",
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox.shrink(),
            Align(
                alignment: Alignment.centerRight,
                child: Text("MP",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-win-header'),
                alignment: Alignment.center,
                child: Text("W",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-draw-header'),
                alignment: Alignment.center,
                child: Text("D",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            const SizedBox.shrink(),
            Align(
                key: const ValueKey('overview-standing-loss-header'),
                alignment: Alignment.center,
                child: Text("L",
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
      children: data.map((r) {
        final bool hl = r["hl"] == true;
        final Color c = hl ? colors.onSurface : muted;
        final FontWeight w = hl ? FontWeight.w700 : FontWeight.w400;

        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8), // gap here
              child: Text("${r["rank"]}",
                  style: TextStyle(color: c, fontWeight: w)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                r["team"],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontWeight: w),
              ),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      Text(r["mp"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  key: ValueKey('overview-standing-win-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["w"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  key: ValueKey('overview-standing-draw-${r["rank"]}'),
                  alignment: Alignment.center,
                  child:
                      Text(r["d"], style: Heading5.style.copyWith(color: c))),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
