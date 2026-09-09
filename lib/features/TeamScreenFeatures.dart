import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository_provider.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/data/transfers/transfer_repository.dart';
import 'package:onetouch/data/transfers/transfer_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_best_eleven.dart';
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
                    onTap: () => context.push('/match/${match.fixtureId}'),
                    child: MatchCard(
                      match: match,
                      leagueName: leagueName,
                      backgroundColor: nextMatchBackground,
                    ),
                  ),
                if (lastMatch != null)
                  GestureDetector(
                    onTap: () => context.push(
                        '/match/${lastMatch.fixtureId}?status=${lastMatch.status.name}'),
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
    if (currentIndex == -1) return allRows.take(3).toList();

    // Slide the 3-row window so it always shows 3 rows (not just clamps each
    // edge independently) — otherwise a team near the top/bottom of a
    // smaller competition (e.g. a 12-team UCL table) gets a shorter window
    // than a team in the middle of a 20-team domestic league, making the
    // two cards different heights.
    const windowSize = 3;
    var start = currentIndex - 1;
    var end = start + windowSize;
    if (start < 0) {
      end -= start;
      start = 0;
    }
    if (end > allRows.length) {
      start -= (end - allRows.length);
      end = allRows.length;
    }
    start = start.clamp(0, allRows.length);
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
        2: FixedColumnWidth(_gapW), // gap
        3: FixedColumnWidth(_statW), // MP
        4: FixedColumnWidth(_statW), // W
        5: FixedColumnWidth(_statW), // D
        6: FixedColumnWidth(_statW), // L
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
            Align(
                alignment: Alignment.centerRight,
                child: Text("W",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            Align(
                alignment: Alignment.centerRight,
                child: Text("D",
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface))),
            Align(
                alignment: Alignment.centerRight,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      Text(r["w"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      Text(r["d"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(
                  alignment: Alignment.centerRight,
                  child:
                      Text(r["l"], style: Heading5.style.copyWith(color: c))),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class BestXI extends StatefulWidget {
  const BestXI({
    super.key,
    this.teams,
    this.repository,
  });

  final teams;
  final BestElevenRepository? repository;

  @override
  State<BestXI> createState() => _BestXIState();
}

class _BestXIState extends State<BestXI> {
  TeamBestEleven? _lineup;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  BestElevenRepository get _repository =>
      widget.repository ?? bestElevenRepository;

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
  void didUpdateWidget(BestXI oldWidget) {
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

    _lineup = cached;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;

    if (_isLoading) {
      unawaited(_loadLineup(teamId!, requestId));
    }
  }

  Future<void> _loadLineup(int teamId, int requestId) async {
    try {
      final lineup = await _repository.loadForTeam(teamId);
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _lineup = lineup;
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

  @override
  Widget build(BuildContext context) {
    if (_teamId == null) return const SizedBox.shrink();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox.square(
            key: ValueKey('best-eleven-loading'),
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_loadFailed) {
      return Padding(
        key: const ValueKey('best-eleven-error'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text('Unable to load best eleven', style: Body2.style),
            ),
            TextButton(onPressed: _retryLoad, child: const Text('RETRY')),
          ],
        ),
      );
    }

    final players = _lineup?.players ?? const <BestElevenEntry>[];
    if (players.isEmpty) {
      return Padding(
        key: const ValueKey('best-eleven-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Text('No best eleven available', style: Body2.style),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: BestElevenPitch(players: players),
    );
  }
}

// Pitch + player-dot rendering for a best-eleven lineup, shared by the Team
// Overview tab (BestXI, above) and the Analysis tab's formation picker so
// both render from the exact same widget rather than near-duplicate UIs.
class BestElevenPitch extends StatelessWidget {
  BestElevenPitch({
    super.key,
    required List<BestElevenEntry> players,
  }) : _players = List.unmodifiable(
          players.map(
            (player) => _BestElevenPitchPlayer(
              slotKey: player.slotKey,
              playerName: player.playerName,
            ),
          ),
        );

  final List<_BestElevenPitchPlayer> _players;

  @override
  Widget build(BuildContext context) {
    if (_players.isEmpty) return const SizedBox.shrink();
    final appColors = AppColors.of(context);
    final pitchBackground = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : appColors.cardBackground;

    final Map<int, List<_BestElevenPitchPlayer>> byRow = {};
    for (final p in _players) {
      final parts = p.slotKey.split(':');
      final row = int.parse(parts[0]);
      byRow.putIfAbsent(row, () => []).add(p);
    }
    // Sort each row by col (left → right on pitch)
    for (final list in byRow.values) {
      list.sort((a, b) {
        final aC = int.parse(a.slotKey.split(':')[1]);
        final bC = int.parse(b.slotKey.split(':')[1]);
        return aC.compareTo(bC);
      });
    }
    // Row keys descending → attack at top, GK at bottom
    final rowKeys = byRow.keys.toList()..sort((a, b) => b.compareTo(a));

    return Material(
      color: pitchBackground,
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: pitchBackground),
        child: Column(
          children: [
            CustomPaint(
              painter: _HalfCirclePainter(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.15),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: rowKeys.map((key) {
                    final rowPlayers = byRow[key]!;
                    return _BestXIRow(
                      players: rowPlayers,
                      isDefRow:
                          key == rowKeys.last, // DEF row gets side-back offset
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

// Draws the faint half-circle arc at the top of the pitch area
class _HalfCirclePainter extends CustomPainter {
  const _HalfCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Half-circle centred at top-centre, radius ~22% of width
    final centre = Offset(size.width / 2, 0);
    final radius = size.width * 0.28;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      0, // start angle (right side)
      3.14159, // sweep = π → bottom half of circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HalfCirclePainter old) => old.color != color;
}

class _BestXIRow extends StatelessWidget {
  final List<_BestElevenPitchPlayer> players;
  // When true, first and last player (SBs) sit slightly higher than CBs
  final bool isDefRow;

  const _BestXIRow({required this.players, this.isDefRow = false});

  @override
  Widget build(BuildContext context) {
    // For def row with 4 players: SBs get negative top padding (shift up),
    // CBs stay at baseline. For all other rows: flat.
    Widget dotWithOffset(int colIndex) {
      double topOffset = 0;
      if (isDefRow && players.length == 4) {
        // col indices 0 (LB) and 3 (RB) → shift up 10px
        if (colIndex == 0 || colIndex == players.length - 1) {
          topOffset = -10;
        }
      }
      return Padding(
        padding: EdgeInsets.only(top: topOffset < 0 ? 0 : 0),
        child: Transform.translate(
          offset: Offset(0, topOffset),
          child: _BestXIPlayerDot(player: players[colIndex]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(players.length, (i) => dotWithOffset(i)),
      ),
    );
  }
}

class _BestXIPlayerDot extends StatelessWidget {
  final _BestElevenPitchPlayer player;
  const _BestXIPlayerDot({required this.player});

  @override
  Widget build(BuildContext context) {
    // Last name only
    final playerName = player.playerName?.trim();
    final label = playerName == null || playerName.isEmpty
        ? 'Unknown'
        : playerName.split(' ').last;
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      width: 62,
      child: Column(
        children: [
          // White circle with ## placeholder (jersey number TBD)
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.onSurface,
            ),
            alignment: Alignment.center,
            child: Text('##',
                // player.jerseyNumber.toString(),
                style: Heading5.style.copyWith(color: colors.onPrimary)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: Eyebrow.style,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _BestElevenPitchPlayer {
  const _BestElevenPitchPlayer({
    required this.slotKey,
    required this.playerName,
  });

  final String slotKey;
  final String? playerName;
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
    final displayType = transfer.displayType ?? '-';
    final isLoan = displayType.contains('Loan');
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
                        displayType,
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
