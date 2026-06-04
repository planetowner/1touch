import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/stylesheet_dark.dart";
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/bestXI.dart';
import 'package:onetouch/models/mock_transfer_bestXI_data.dart';
import 'package:intl/intl.dart';
import '../models/league.dart';
import '../models/transfer.dart';

String _formatMatchDate(String startingAt) {
  final dt = DateTime.parse(startingAt).toLocal();
  return DateFormat('EEE, MMM d h:mm a').format(dt);
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
    final leagueName = leagueNames[match?.leagueId ?? lastMatch?.leagueId] ?? "Unknown League";

    if (match == null && lastMatch == null) return const SizedBox.shrink();


    return SizedBox(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Material(
          elevation: 0,
          color: const Color(0xFF272828),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
                color: Color(0xFF272828)
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
                    ),
                  ),
                if (lastMatch != null)
                  GestureDetector(
                    onTap: () => context.push('/match/${lastMatch.fixtureId}?status=${lastMatch.status.name}'),
                    child: () {
                      final home = mockTeamById(lastMatch.homeTeamId);
                      final away = mockTeamById(lastMatch.awayTeamId);
                      return MatchCard2(
                        date: _formatMatchDate(lastMatch.startingAt),
                        venue: '',
                        team1shortname: home.shortCode ?? home.name,
                        team1Logo: home.imagePath ?? '',
                        team2shortname: away.shortCode ?? away.name,
                        team2Logo: away.imagePath ?? '',
                        homeScore: lastMatch.homeScore ?? 0,
                        awayScore: lastMatch.awayScore ?? 0,
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
  // colors
  static const Color _bodyColor    = Color(0xFF272828);
  static const Color _headerColor  = Color(0xFF3D3D3D);
  static const Color _dividerColor = Color(0xFF2B2B2B);

  // grid widths (tweak if needed)
  static const double _rankW = 32;
  static const double _gapW  = 16;
  static const double _statW = 28;

  @override
  Widget build(BuildContext context) {
    // Resolve team and leagueId from widget.teams
    int? leagueId;
    int? currentTeamId;
    if (widget.teams is Map<String, dynamic>) {
      final map = widget.teams as Map<String, dynamic>;
      currentTeamId = map['id'] as int?;
      final nextMatch = map['next_match'] as Fixture?;
      final lastMatch = map['last_match'] as Fixture?;
      leagueId = nextMatch?.leagueId ?? lastMatch?.leagueId;
    }

    if (leagueId == null) return const SizedBox.shrink();

    final leagueName = leagueNames[leagueId] ?? 'League';
    final standings = standingsByLeague(leagueId);

    final allRows = standings.map((s) => {
      'rank': s.position,
      'team': mockTeamById(s.teamId).shortCode ?? mockTeamById(s.teamId).name,
      'mp': s.matchesPlayed.toString(),
      'w': s.won.toString(),
      'd': s.draw.toString(),
      'l': s.lost.toString(),
      'hl': s.teamId == currentTeamId,
    }).toList();

    final currentIndex = allRows.indexWhere((r) => r['hl'] == true);
    final start = (currentIndex - 2).clamp(0, allRows.length);
    final end   = (currentIndex + 3).clamp(0, allRows.length);
    final rows  = currentIndex == -1 ? allRows.take(5).toList() : allRows.sublist(start, end);

    return SizedBox(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStandingCard(leagueName, rows: rows, isFirst: true, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStandingCard(String leagueName, {required List<Map<String, dynamic>> rows, required bool isFirst, required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(
        left: isFirst ? 24 : 0,
        right: isLast ? 24 : 16,
        top: 16,
        bottom: 16,
      ),
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: 345,
          decoration: const BoxDecoration(color: _bodyColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header block
              Container(
                color: _headerColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24,),
                    // league title line
                    Row(
                      children: [
                        Image.asset(
                          'assets/laliga.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 10),
                        Text(leagueName, style: Heading4.style),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // columns header line (uses same table grid as body)
                    _columnsHeader(),
                    SizedBox(height: 12,),
                  ],
                ),
              ),
              // divider
              Container(height: 1, color: _dividerColor),

              // body rows table (aligned with header)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
    1: FlexColumnWidth(),        // Club
    2: FixedColumnWidth(_gapW),  // gap
    3: FixedColumnWidth(_statW), // MP
    4: FixedColumnWidth(_statW), // W
    5: FixedColumnWidth(_statW), // D
    6: FixedColumnWidth(_statW), // L
  };

  Widget _columnsHeader() {
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: const [
        TableRow(
          children: [
            Text("#", style: TextStyle(color: Colors.white)),
            Text("Club", overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white)),
            SizedBox.shrink(),
            Align(alignment: Alignment.centerRight, child: Text("MP", style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("W",  style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("D",  style: TextStyle(color: Colors.white))),
            Align(alignment: Alignment.centerRight, child: Text("L",  style: TextStyle(color: Colors.white))),
          ],
        ),
      ],
    );
  }

  Widget _rowsTable(List<Map<String, dynamic>> data) {
    return Table(
      columnWidths: _grid,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: data.map((r) {
        final bool hl = r["hl"] == true;
        final Color c = hl ? Colors.white : Colors.white54;
        final FontWeight w = hl ? FontWeight.w700 : FontWeight.w400;

        return TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8), // gap here
              child: Text("${r["rank"]}", style: TextStyle(color: c, fontWeight: w)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(r["team"], overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontWeight: w)),
            ),
            const SizedBox.shrink(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["mp"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["w"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["d"], style: Heading5.style.copyWith(color: c))),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Align(alignment: Alignment.centerRight,
                  child: Text(r["l"], style: Heading5.style.copyWith(color: c))),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class BestXI extends StatelessWidget {
  const BestXI({super.key, this.teams});

  final teams;

  @override
  Widget build(BuildContext context) {
    // Resolve team_id from the map
    int? teamId;
    if (teams is Map<String, dynamic>) {
      teamId = (teams as Map<String, dynamic>)['id'] as int?;
    }

    final players = teamId != null
        ? bestElevenByTeam(teamId)
        : <BestElevenPlayer>[];

    if (players.isEmpty) return const SizedBox.shrink();


    final Map<int, List<BestElevenPlayer>> byRow = {};
    for (final p in players) {
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
    final formationLabel = players.first.formation; // e.g. '4-3-3'

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Material(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Color(0xFF3D3D3D)),
          child: Column(
            children: [
              // Formation
              // Padding(
              //   padding: const EdgeInsets.only(top: 16, bottom: 4),
              //   // child: Text(formationLabel, style: Body2.style),
              // ),
              CustomPaint(
                painter: _HalfCirclePainter(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: rowKeys.map((key) {
                      final rowPlayers = byRow[key]!;
                      return _BestXIRow(
                        players: rowPlayers,
                        isDefRow: key == rowKeys.last, // DEF row gets side-back offset
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// Draws the faint half-circle arc at the top of the pitch area
class _HalfCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Half-circle centred at top-centre, radius ~22% of width
    final centre = Offset(size.width / 2, 0);
    final radius = size.width * 0.28;
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      0,        // start angle (right side)
      3.14159,  // sweep = π → bottom half of circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_HalfCirclePainter old) => false;
}

class _BestXIRow extends StatelessWidget {
  final List<BestElevenPlayer> players;
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
  final BestElevenPlayer player;
  const _BestXIPlayerDot({required this.player});

  @override
  Widget build(BuildContext context) {
    // Last name only
    final label = player.playerName.split(' ').last;

    return SizedBox(
      width: 62,
      child: Column(
        children: [
          // White circle with ## placeholder (jersey number TBD)
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: Text(
              '##',
                // player.jerseyNumber.toString(),
              style: Heading5.style.copyWith(color: Colors.black)
            ),
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
            ...injuredPlayers
                .map((player) => _buildInjuryTile(player))
                ,
          ],
        ));
  }

  Widget _buildInjuryTile(Map<String, String> player) {
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
                backgroundColor: Color(0xFF272828),
              ),

              // Jersey number in top-left badge
              Positioned(
                top: -5, // Slightly overlaps the top edge
                left: -10, // Slightly overlaps the left edge
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF3D3D3D),
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
  const Transfer({super.key, this.teams});

  final teams;

  @override
  State<Transfer> createState() => _TransferState();
}

class _TransferState extends State<Transfer> {
  bool showIn = true; // true = IN, false = OUT

  String _formatFee(int? amount) {
    if (amount == null) return 'On Loan';
    if (amount == 0) return 'Free Agent';
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '€${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}m';
    }
    return '€${(amount / 1000).toStringAsFixed(0)}k';
  }

  String _formatDate(String date) {
    try {
      final dt = DateTime.parse(date);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return date;
    }
  }

  @override
  Widget build(BuildContext context) {
    int? teamId;
    if (widget.teams is Map<String, dynamic>) {
      teamId = (widget.teams as Map<String, dynamic>)['id'] as int?;
    }

    final incoming = teamId != null ? incomingTransfers(teamId) : <TeamTransfer>[];
    final outgoing = teamId != null ? outgoingTransfers(teamId) : <TeamTransfer>[];
    final list = showIn ? incoming : outgoing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TRANSFER SWITCH BUTTON
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => showIn = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: showIn ? const Color(0xFF3D3D3D) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF3D3D3D)),
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
                  onTap: () => setState(() => showIn = false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: !showIn ? const Color(0xFF3D3D3D) : Colors.transparent,
                      border: Border.all(color: const Color(0xFF3D3D3D)),
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
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text('No transfers', style: Body2.style),
          )
        else
          ...list.map((t) => TransferTile(
            transfer: t,
            showIn: showIn,
            feeLabel: _formatFee(t.amount),
            dateLabel: _formatDate(t.transferDate),
          )),

        const SizedBox(height: 8),
      ],
    );
  }
}

class TransferTile extends StatelessWidget {
  final TeamTransfer transfer;
  final bool showIn;
  final String feeLabel;
  final String dateLabel;

  const TransferTile({
    super.key,
    required this.transfer,
    required this.showIn,
    required this.feeLabel,
    required this.dateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final counterTeam = showIn ? transfer.fromTeamName : transfer.toTeamName;
    // Loan badge colour vs transfer
    final isLoan = transfer.typeName == TransferType.loan;

    return Container(
      margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Player photo
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF3D3D3D),
            child: ClipOval(
              child: Image.network(
                transfer.playerImage,
                width: 68,
                height: 68,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/messi.png',
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                )
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
                        transfer.playerName,
                        style: Heading5.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(feeLabel, style: Heading5.style),
                  ],
                ),
                const SizedBox(height: 6),

                // FROM / TO badge + team name
                Row(
                  children: [
                    Badge(label: showIn ? 'FROM' : 'TO'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        counterTeam,
                        style: Body1.style,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // DATE badge + formatted date, LOAN chip if applicable
                Row(
                  children: [
                    Badge(label: 'DATE'),
                    const SizedBox(width: 8),
                    Text(dateLabel, style: Body1.style),
                    if (isLoan) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD82457).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LOAN',
                          style: Eyebrow.style.copyWith(
                              color: const Color(0xFFD82457)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Eyebrow.style),
    );
  }
}
