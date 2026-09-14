import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_transfer_window.dart';
import 'package:intl/intl.dart';

String _formatMatchDate(DateTime? kickoff) {
  if (kickoff == null) return 'Date TBD';
  return DateFormat('EEE, MMM d h:mm a').format(kickoff.toLocal());
}

class Fixtures extends StatefulWidget {
  Fixtures({super.key, this.teams});

  final teams;

  @override
  State<Fixtures> createState() => _FixturesState();
}

class _FixturesState extends State<Fixtures> {
  @override
  Widget build(BuildContext context) {
    if (widget.teams == null) return const SizedBox.shrink();
    if (widget.teams is! Map<String, dynamic>) return const SizedBox.shrink();

    final map = widget.teams as Map<String, dynamic>;
    final Fixture? match = map['next_match'] as Fixture?;
    final Fixture? lastMatch = map['last_match'] as Fixture?;
    final competitionId = match?.competitionId ?? lastMatch?.competitionId;
    final leagueName = competitionId == null
        ? 'Unknown League'
        : competitionRepository.findById(competitionId)?.name ??
            'Unknown League';

    if (match == null && lastMatch == null) return const SizedBox.shrink();
    final appColors = AppColors.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final nextMatchBackground =
        isLight ? AppPalette.white : appColors.subtleBackground;
    final lastMatchBackground =
        isLight ? AppPalette.lightGreyBox : appColors.cardBackground;

    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Material(
          elevation: 0,
          color: appColors.cardBackground,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            key: const ValueKey('team-overview-fixtures-card'),
            padding: EdgeInsets.only(bottom: isLight ? 0 : 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: appColors.cardBackground,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (match != null)
                  GestureDetector(
                    onTap: () => context.push(
                      '/match/${match.fixtureId}',
                      extra: match,
                    ),
                    child: MatchCard(
                      match: match,
                      leagueName: leagueName,
                      backgroundColor: nextMatchBackground,
                    ),
                  ),
                if (lastMatch != null)
                  GestureDetector(
                    onTap: () => context.push(
                      '/match/${lastMatch.fixtureId}?status=${lastMatch.status.name}',
                      extra: lastMatch,
                    ),
                    child: () {
                      final home = teamRepository
                          .findByIdOrUnknown(lastMatch.homeTeamId);
                      final away = teamRepository
                          .findByIdOrUnknown(lastMatch.awayTeamId);
                      return MatchCard2(
                        date: _formatMatchDate(lastMatch.kickoff),
                        venue: '',
                        team1shortname: home.shortCode ?? home.name,
                        team1Logo: home.imagePath ?? '',
                        team1Id: home.teamId,
                        team2shortname: away.shortCode ?? away.name,
                        team2Logo: away.imagePath ?? '',
                        team2Id: away.teamId,
                        homeScore: lastMatch.homeScore ?? 0,
                        awayScore: lastMatch.awayScore ?? 0,
                        backgroundColor: lastMatchBackground,
                        contentPadding: isLight
                            ? const EdgeInsets.fromLTRB(16, 16, 16, 24)
                            : null,
                      );
                    }(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Standing extends StatefulWidget {
  const Standing({super.key, this.teams});
  final teams;

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
      final team = teamRepository.findByIdOrUnknown(s.teamId);
      return {
        'rank': s.position,
        'team': team.shortCode ?? team.name,
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

class InjuryStatus extends StatefulWidget {
  const InjuryStatus({super.key, this.teams});

  final teams;

  @override
  State<InjuryStatus> createState() => _InjuryStatusState();
}

class _InjuryStatusState extends State<InjuryStatus> {
  final List<Map<String, String>> injuredPlayers = [
    {
      'number': '10',
      'name': 'Player Name',
      'injury': 'Hamstring',
      'weeks': '3',
      'image': 'assets/messi.png',
    },
    {
      'number': '8',
      'name': 'Player Name',
      'injury': 'Ankle Sprain',
      'weeks': '5',
      'image': 'assets/messi.png',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...injuredPlayers.map((player) => _buildInjuryTile(player)),
          ],
        ));
  }

  Widget _buildInjuryTile(Map<String, String> player) {
    final appColors = AppColors.of(context);
    return Container(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player Circle with Placeholder
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Main player image circle
              CircleAvatar(
                radius: 37,
                backgroundImage: const AssetImage('assets/messi.png'),
                backgroundColor: appColors.cardBackground,
              ),

              // Jersey number in top-left badge
              Positioned(
                top: -5, // Slightly overlaps the top edge
                left: -10, // Slightly overlaps the left edge
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: appColors.subtleBackground,
                  child: Text(player['number'] ?? '#', style: Body2_b.style),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player['name'] ?? '', style: Body1_b.style),
                const SizedBox(height: 4),
                Text('${player['injury']} • Back in ${player['weeks']} weeks',
                    style: Body2.style),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Transfer extends StatefulWidget {
  const Transfer({
    super.key,
    this.teams,
    this.repository,
  });

  final teams;
  final TransferRepository? repository;

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  bool showIn = true; // true = IN, false = OUT
  TeamTransferWindow? _window;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  TransferRepository get _repository => widget.repository ?? transferRepository;

  int? get _teamId {
    if (widget.teams is Map<String, dynamic>) {
      return (widget.teams as Map<String, dynamic>)['id'] as int?;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(Transfer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldTeamId = oldWidget.teams is Map<String, dynamic>
        ? (oldWidget.teams as Map<String, dynamic>)['id'] as int?
        : null;
    if (_teamId != oldTeamId || widget.repository != oldWidget.repository) {
      _startLoad();
    }
  }

  void _startLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _window = cached;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;

    if (_isLoading) {
      unawaited(_loadTransfers(teamId!, requestId));
    }
  }

  Future<void> _loadTransfers(int teamId, int requestId) async {
    try {
      final window = await _repository.loadForTeam(teamId);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _window = window;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _retryLoad() => setState(_startLoad);

  String _formatDate(String? date) {
    if (date == null || date.isEmpty) return '-';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(date));
    } on FormatException {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final incoming = _window?.incoming ?? const <TransferEntry>[];
    final outgoing = _window?.outgoing ?? const <TransferEntry>[];
    final list = showIn ? incoming : outgoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRANSFER SWITCH BUTTON
        Padding(
          padding:
              const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('transfer-in-toggle'),
                  onTap: () => setState(() => showIn = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: showIn
                          ? appColors.subtleBackground
                          : Colors.transparent,
                      border: Border.all(color: appColors.subtleBackground),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text("IN", style: Body2_b.style),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('transfer-out-toggle'),
                  onTap: () => setState(() => showIn = false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !showIn
                          ? appColors.subtleBackground
                          : Colors.transparent,
                      border: Border.all(color: appColors.subtleBackground),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text("OUT", style: Body2_b.style),
                  ),
                ),
              ),
            ],
          ),
        ),

        // PLAYER LIST
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox.square(
                key: ValueKey('transfer-loading'),
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_loadFailed)
          Padding(
            key: const ValueKey('transfer-error'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Unable to load transfers', style: Body2.style),
                ),
                TextButton(onPressed: _retryLoad, child: const Text('RETRY')),
              ],
            ),
          )
        else if (list.isEmpty)
          Padding(
            key: const ValueKey('transfer-empty'),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('No transfers', style: Body2.style),
          )
        else
          ...list.map((t) => TransferTile(
                transfer: t,
                dateLabel: _formatDate(t.transferDate),
              )),

        const SizedBox(height: 8),
      ],
    );
  }
}

class TransferTile extends StatelessWidget {
  final TransferEntry transfer;
  final String dateLabel;

  const TransferTile({
    super.key,
    required this.transfer,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final playerImage = transfer.playerImage;
    final transferValue = _transferValue(transfer);
    final isLoan = (transfer.displayType ?? '').contains('Loan');
    final appColors = AppColors.of(context);

    return Container(
      key: ValueKey('transfer-${transfer.transferId}'),
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player photo
          CircleAvatar(
            radius: 36,
            backgroundColor: appColors.subtleBackground,
            child: ClipOval(
              child: playerImage == null || playerImage.isEmpty
                  ? Image.asset(
                      'assets/messi.png',
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    )
                  : Image.network(
                      playerImage,
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/messi.png',
                        width: 68,
                        height: 68,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name, Fee
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        transfer.playerName ?? 'Unknown Player',
                        style: Heading5.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        transferValue,
                        style: Heading5.style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // FROM / TO badge + team name
                Row(
                  children: [
                    Badge(
                      label: transfer.direction == TransferDirection.incoming
                          ? 'FROM'
                          : 'TO',
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transfer.otherTeamName ?? 'Unknown Team',
                        style: Body1.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // DATE badge + formatted date, LOAN chip if applicable
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Badge(label: 'DATE'),
                    Text(dateLabel, style: Body1.style),
                    if (isLoan) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD82457).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOAN',
                          style: Eyebrow.style
                              .copyWith(color: const Color(0xFFD82457)),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _transferValue(TransferEntry transfer) {
    if (transfer.typeId != 219) {
      return transfer.displayType ?? '-';
    }
    if (transfer.amount == null) return 'Unknown';

    // Temporary frontend-only rule: verified Sportmonks fixtures and public
    // fees indicate confirmed transfer amounts are EUR. Remove this assumption
    // when the backend starts returning authoritative currency metadata.
    return '€${_compactAmount(transfer.amount!)}';
  }

  static String _compactAmount(int amount) {
    if (amount >= 1000000000) {
      return '${_scaledAmount(amount, 1000000000)}bn';
    }
    if (amount >= 1000000) {
      return '${_scaledAmount(amount, 1000000)}m';
    }
    if (amount >= 1000) {
      return '${_scaledAmount(amount, 1000)}k';
    }
    return '$amount';
  }

  static String _scaledAmount(int amount, int divisor) {
    final scaled = amount / divisor;
    return scaled == scaled.roundToDouble()
        ? scaled.toInt().toString()
        : scaled.toStringAsFixed(1);
  }
}

class Badge extends StatelessWidget {
  final String label;
  const Badge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.subtleBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Eyebrow.style),
    );
  }
}
