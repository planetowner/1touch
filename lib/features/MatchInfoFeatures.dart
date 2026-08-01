import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/home/home_content_service.dart';
import 'package:onetouch/models/match_data.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:url_launcher/url_launcher.dart';

enum LineupEventType {
  yellowCard,
  redCard,
  goal,
  subIn,
  subOut,
  assist,
  injury
}

class LineupEvent {
  final LineupEventType type;
  final int? minute;
  const LineupEvent({required this.type, this.minute});
}

class LineupPlayer {
  final int number;
  final String name;
  final List<LineupEvent> events;
  const LineupPlayer({
    required this.number,
    required this.name,
    this.events = const [],
  });
}

class MatchScoreHeader extends StatelessWidget {
  final String homeLogoAsset;
  final String awayLogoAsset;
  final int homeTeamId;
  final int awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final String homeScore;
  final String awayScore;
  final String statusLabel; // "Final" or live clock e.g. "42:02"
  final String roundLabel; // e.g. "R16", "RO 33"

  const MatchScoreHeader({
    super.key,
    required this.homeLogoAsset,
    required this.awayLogoAsset,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.statusLabel,
    required this.roundLabel,
  });

  @override
  Widget build(BuildContext context) {
    // Dim whichever side lost — only when both scores actually parse (e.g.
    // not the '#' placeholder used before a fixture has a result yet).
    final home = int.tryParse(homeScore);
    final away = int.tryParse(awayScore);
    final homeDimmed = home != null && away != null && home < away;
    final awayDimmed = home != null && away != null && away < home;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child: _TeamBlock(
                teamId: homeTeamId,
                logoAsset: homeLogoAsset,
                name: homeTeamName)),
        const SizedBox(width: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(roundLabel, style: Body2.style),
            const SizedBox(height: 8),
            Row(
              children: [
                _ScoreBox(score: homeScore, isDimmed: homeDimmed),
                const SizedBox(width: 8),
                _ScoreBox(score: awayScore, isDimmed: awayDimmed),
              ],
            ),
            const SizedBox(height: 16),
            Text(statusLabel, style: Body2_b.style),
          ],
        ),
        const SizedBox(width: 20),
        Expanded(
            child: _TeamBlock(
                teamId: awayTeamId,
                logoAsset: awayLogoAsset,
                name: awayTeamName)),
      ],
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final int teamId;
  final String logoAsset;
  final String name;
  const _TeamBlock(
      {required this.teamId, required this.logoAsset, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          // The match screen is pushed on the root navigator (see
          // parentNavigatorKey on '/match/:matchId' in main.dart), but
          // '/team/:id' lives inside the bottom-nav shell's own navigator —
          // push() would land there invisibly, behind this screen. go()
          // replaces the location so the shell actually surfaces.
          onTap: () => context.go('/team/$teamId'),
          child: Image.network(
            logoAsset,
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 72),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: Body1.style,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String score;
  final bool isDimmed;
  const _ScoreBox({required this.score, this.isDimmed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        score,
        style: Heading1.style
            .copyWith(color: isDimmed ? Colors.grey : Colors.white),
      ),
    );
  }
}

// One row of the match-events list: a player plus every minute they're
// credited for this event type, e.g. a brace shows as "23',67'" on one row
// rather than two separate rows.
class _GroupedMatchEvent {
  final String player;
  final String team; // 'home' | 'away'
  final String type; // 'goal' | 'redCard'
  final List<String> minutes;
  _GroupedMatchEvent(
      {required this.player, required this.team, required this.type})
      : minutes = [];
}

List<_GroupedMatchEvent> _groupMatchEvents(List<Map<String, dynamic>> events) {
  final rows = <_GroupedMatchEvent>[];
  for (final e in events) {
    final team = e['team'] as String;
    final player = e['player'] as String;
    final type = (e['type'] as String?) ?? 'goal';
    final existing = rows
        .where((r) => r.team == team && r.player == player && r.type == type)
        .firstOrNull;
    final row =
        existing ?? _GroupedMatchEvent(player: player, team: team, type: type);
    if (existing == null) rows.add(row);
    row.minutes.add(e['minute'] as String);
  }
  return rows;
}

// A goal/red-card icon, shared by one whole section of rows rather than
// repeated per row — there's one ball icon for the goals section and one
// card icon for the red-cards section, not one per scorer.
Widget _eventTypeIcon(String type) {
  if (type == 'redCard') {
    return Container(
      width: 9,
      height: 13,
      decoration: BoxDecoration(
        color: const Color(0xFFE8000A),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
  return Container(
    width: 16,
    height: 16,
    alignment: Alignment.center,
    decoration:
        const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
    child: const Icon(Icons.sports_soccer, size: 12, color: Colors.black),
  );
}

class MatchEventsSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const MatchEventsSection({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final rows = _groupMatchEvents(events);
    final goalRows = rows.where((r) => r.type == 'goal').toList();
    final redCardRows = rows.where((r) => r.type == 'redCard').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          ..._buildSection(goalRows),
          ..._buildSection(redCardRows),
        ],
      ),
    );
  }

  // Renders one section's rows with a single center icon, shown only
  // alongside the first row — the rest of the section's rows leave that
  // center slot empty rather than repeating the icon.
  List<Widget> _buildSection(List<_GroupedMatchEvent> rows) {
    return List.generate(rows.length, (i) {
      final row = rows[i];
      final isHome = row.team == 'home';
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: isHome
                  ? _EventRowContent(row: row, alignRight: false)
                  : const SizedBox.shrink(),
            ),
            SizedBox(
              width: 20,
              child: i == 0 ? Center(child: _eventTypeIcon(row.type)) : null,
            ),
            Expanded(
              child: !isHome
                  ? _EventRowContent(row: row, alignRight: true)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    });
  }
}

class _EventRowContent extends StatelessWidget {
  final _GroupedMatchEvent row;
  final bool alignRight;
  const _EventRowContent({required this.row, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    final minuteText = Text(row.minutes.join(','), style: Eyebrow.style);
    final nameText = Flexible(
      child: Text(row.player,
          style: Eyebrow.style, overflow: TextOverflow.ellipsis),
    );

    // Minute always flares to the outer edge, name leans toward the shared
    // center icon — mirrored between the home (left) and away (right) side.
    final children = alignRight
        ? [nameText, const SizedBox(width: 6), minuteText]
        : [minuteText, const SizedBox(width: 6), nameText];

    return Row(
      mainAxisAlignment:
          alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: children,
    );
  }
}

class MatchHighlights extends StatefulWidget {
  final String imageAsset;
  final int homeTeamId;
  final int awayTeamId;

  const MatchHighlights({
    super.key,
    required this.imageAsset,
    required this.homeTeamId,
    required this.awayTeamId,
  });

  @override
  State<MatchHighlights> createState() => _MatchHighlightsState();
}

class _MatchHighlightsState extends State<MatchHighlights> {
  final HomeContentService _contentService = HomeContentService();
  HomeContentItem? _highlight;
  bool _networkImageFailed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _loadHighlight();
  }

  @override
  void didUpdateWidget(MatchHighlights oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.homeTeamId != widget.homeTeamId ||
        oldWidget.awayTeamId != widget.awayTeamId) {
      _highlight = null;
      _networkImageFailed = false;
      _loadHighlight();
    }
  }

  Future<void> _loadHighlight() async {
    final requestId = ++_requestId;
    final highlight = await _contentService.fetchMatchHighlight(
      homeTeamId: widget.homeTeamId,
      awayTeamId: widget.awayTeamId,
    );
    if (!mounted || requestId != _requestId) return;
    setState(() {
      _highlight = highlight;
      _networkImageFailed = false;
    });
  }

  Future<void> _openHighlight() async {
    final uri = Uri.tryParse(_highlight?.destinationUrl ?? '');
    if (uri == null || _networkImageFailed) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleImageError() {
    if (_networkImageFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_networkImageFailed) {
        setState(() => _networkImageFailed = true);
      }
    });
  }

  @override
  void dispose() {
    _contentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canOpen = _highlight?.destinationUrl?.isNotEmpty == true &&
        !_networkImageFailed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HIGHLIGHTS", style: Body2_b.style),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canOpen ? _openHighlight : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _buildImage(),
          ),
        ),
      ],
    );
  }

  Widget _buildImage() {
    final imageUrl = _highlight?.imageUrl;
    if (!_networkImageFailed && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: double.infinity,
        height: 194,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _handleImageError();
          return _fallbackImage();
        },
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      widget.imageAsset,
      width: double.infinity,
      height: 194,
      fit: BoxFit.cover,
    );
  }
}

class PlayerOfTheMatch extends StatelessWidget {
  final String rating;
  final String playerName;
  final String teamAndNumber; // e.g. "FC Barcelona • 9"

  const PlayerOfTheMatch({
    super.key,
    required this.rating,
    required this.playerName,
    required this.teamAndNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PLAYER OF THE MATCH", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xCC272929),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_outlined,
                      color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Text(rating, style: Heading2.style),
                ],
              ),
              const SizedBox(height: 42),
              Text(playerName,
                  style: Heading5.style,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(teamAndNumber,
                  style: Body2.style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class MomentumChart extends StatelessWidget {
  const MomentumChart({super.key, this.values = _defaultMomentum});

  final List<double> values;

  // Mock per-5-minute momentum series, -100..100 (negative = away team
  // dominance, positive = home team), 0' through 90' inclusive.
  static const List<double> _defaultMomentum = [
    -40,
    -70,
    -50,
    -55,
    -35,
    10,
    45,
    75,
    90,
    60,
    40,
    55,
    30,
    0,
    -20,
    -5,
    25,
    40,
    30,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("MOMENTUM", style: Body2_b.style),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          decoration: BoxDecoration(
            color: const Color(0xFF272828),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: CustomPaint(painter: _MomentumPainter(values)),
              ),
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("0’",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text("45’",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  Text("90’",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MomentumPainter extends CustomPainter {
  final List<double> values;
  const _MomentumPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxAbs = values.map((v) => v.abs()).reduce((a, b) => a > b ? a : b);
    final centerY = size.height / 2;
    final scaleY = maxAbs == 0 ? 1.0 : (size.height / 2 - 4) / maxAbs;

    Offset pointAt(int i) {
      final x = size.width * i / (values.length - 1);
      final y = centerY - values[i] * scaleY;
      return Offset(x, y);
    }

    final points = List.generate(values.length, pointAt);

    _drawDashedLine(canvas, Offset(0, centerY), Offset(size.width, centerY),
        Colors.white.withValues(alpha: 0.3));
    final midX = size.width / 2;
    _drawDashedLine(canvas, Offset(midX, 0), Offset(midX, size.height),
        Colors.white.withValues(alpha: 0.3));

    final abovePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x8CFF5B5B), Color(0x0DFF5B5B)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, centerY));
    final belowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.05)
        ],
      ).createShader(
          Rect.fromLTWH(0, centerY, size.width, size.height - centerY));

    for (var i = 0; i < points.length - 1; i++) {
      _fillSegment(
          canvas, points[i], points[i + 1], centerY, abovePaint, belowPaint);
    }

    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);
  }

  // Fills the trapezoid between [a]→[b] and the zero baseline, splitting at
  // the exact zero-crossing when the segment switches sides so the fill
  // boundary tracks the dashed baseline precisely rather than overshooting.
  void _fillSegment(Canvas canvas, Offset a, Offset b, double centerY,
      Paint abovePaint, Paint belowPaint) {
    final aAbove = a.dy <= centerY;
    final bAbove = b.dy <= centerY;

    if (aAbove == bAbove) {
      final path = Path()
        ..moveTo(a.dx, centerY)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, centerY)
        ..close();
      canvas.drawPath(path, aAbove ? abovePaint : belowPaint);
      return;
    }

    final t = (centerY - a.dy) / (b.dy - a.dy);
    final cross = Offset(a.dx + (b.dx - a.dx) * t, centerY);

    canvas.drawPath(
      Path()
        ..moveTo(a.dx, centerY)
        ..lineTo(a.dx, a.dy)
        ..lineTo(cross.dx, cross.dy)
        ..close(),
      aAbove ? abovePaint : belowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cross.dx, cross.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, centerY)
        ..close(),
      bAbove ? abovePaint : belowPaint,
    );
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Color color) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    final totalLength = (end - start).distance;
    final dx = (end.dx - start.dx) / totalLength;
    final dy = (end.dy - start.dy) / totalLength;
    var distance = 0.0;
    while (distance < totalLength) {
      final segEnd = (distance + dashWidth).clamp(0, totalLength);
      canvas.drawLine(
        Offset(start.dx + dx * distance, start.dy + dy * distance),
        Offset(start.dx + dx * segEnd, start.dy + dy * segEnd),
        paint,
      );
      distance += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _MomentumPainter oldDelegate) =>
      oldDelegate.values != values;
}

class StatBarsSection extends StatelessWidget {
  final List<StatBarData> bars;

  const StatBarsSection({super.key, required this.bars});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bars.map((b) => StatComparisonBar(data: b)).toList(),
    );
  }
}

class StatBarData {
  final String category;
  final double homePercent;
  final double awayPercent;

  /// Percentage stats show "63%"; count stats (shots, corners…) show the
  /// raw value and only use the numbers to proportion the bar.
  final bool isPercent;

  const StatBarData({
    required this.category,
    required this.homePercent,
    required this.awayPercent,
    this.isPercent = true,
  });
}

class StatComparisonBar extends StatelessWidget {
  final StatBarData data;

  const StatComparisonBar({super.key, required this.data});

  String _fmt(double v) {
    final number = v % 1 == 0 ? v.toInt().toString() : v.toString();
    return data.isPercent ? '$number%' : number;
  }

  @override
  Widget build(BuildContext context) {
    final total = data.homePercent + data.awayPercent;
    final homeFlex =
        total == 0 ? 50 : (data.homePercent / total * 100).round();
    final awayFlex = 100 - homeFlex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Center(
              child: Text(data.category.toUpperCase(), style: Body2_b.style)),
          const SizedBox(height: 6),
          Row(
            children: [
              // Fixed-width value columns so every bar spans the same width
              // no matter how many digits the values have.
              SizedBox(
                width: 44,
                child: Text(_fmt(data.homePercent),
                    style: Body2.style, textAlign: TextAlign.left),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Expanded(
                          flex: homeFlex,
                          child: Container(height: 8, color: Colors.redAccent)),
                      Expanded(
                          flex: awayFlex,
                          child: Container(height: 8, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(_fmt(data.awayPercent),
                    style: Body2.style, textAlign: TextAlign.right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LineupPitch extends StatelessWidget {
  /// Away team rows ordered GK → attackers (displayed top → bottom).
  final List<List<LineupPlayer>> awayRows;

  /// Home team rows ordered attackers → GK (displayed top → bottom in their half).
  final List<List<LineupPlayer>> homeRows;

  /// Called when the user taps a player dot.
  final void Function(BuildContext context, LineupPlayer player) onPlayerTap;

  const LineupPitch({
    super.key,
    required this.awayRows,
    required this.homeRows,
    required this.onPlayerTap,
  });

  static const double _centerGap = 64;
  // Total pitch height — generous enough for either half to hold ~5-6 rows
  // comfortably. Bounded on purpose: each half below is `Expanded`, and
  // `MainAxisAlignment.spaceBetween` spreads whatever rows it actually has
  // evenly across that space — so the row *count* alone decides the
  // spacing, with no per-row pixel guess and no leftover gap anywhere.
  static const double _pitchHeight = 820;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LINEUP", style: Body2_b.style),
        const SizedBox(height: 12),
        Container(
          height: _pitchHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(
                  child: CustomPaint(painter: _PitchMarkingsPainter())),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 4),
                child: Column(
                  children: [
                    // Away: GK pinned to the top edge, attackers pinned to
                    // the halfway line — whatever rows fall in between
                    // spread out evenly across this half automatically.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final row in awayRows)
                            _PlayerRow(
                              players: row,
                              isHome: false,
                              onTap: (p) => onPlayerTap(context, p),
                            ),
                        ],
                      ),
                    ),
                    // Gap that the center circle overlaps
                    const SizedBox(height: _centerGap),
                    // Home: attackers pinned to the halfway line, GK
                    // pinned to the bottom edge, same even spread.
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final row in homeRows)
                            _PlayerRow(
                              players: row,
                              isHome: true,
                              onTap: (p) => onPlayerTap(context, p),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── One formation row ──

class _PlayerRow extends StatelessWidget {
  final List<LineupPlayer> players;
  final bool isHome;
  final void Function(LineupPlayer) onTap;

  const _PlayerRow({
    required this.players,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: players
          .map((p) =>
              _PlayerDot(player: p, isHome: isHome, onTap: () => onTap(p)))
          .toList(),
    );
  }
}

// ── Single player dot: circle + badges + name ──

class _PlayerDot extends StatelessWidget {
  final LineupPlayer player;
  final bool isHome;
  final VoidCallback onTap;

  const _PlayerDot({
    required this.player,
    required this.isHome,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final minute =
        player.events.map((e) => e.minute).whereType<int>().firstOrNull;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _PlayerCircle(number: player.number, isHome: isHome),
                  if (player.events.isNotEmpty)
                    Positioned(
                      right: -3,
                      bottom: -2,
                      child: _EventBadges(events: player.events),
                    ),
                  if (minute != null)
                    Positioned(
                      left: 40,
                      bottom: -5,
                      child: Center(
                        child: Text("$minute'", style: Body2.style),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              player.name,
              style: Eyebrow.style,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Player circle ──

class _PlayerCircle extends StatelessWidget {
  final int number;
  final bool isHome;

  const _PlayerCircle({required this.number, required this.isHome});

  static const _accent = Color(0xFFD82457);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isHome ? _accent : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text('$number',
            style: Heading5.style.copyWith(
              color: isHome ? Colors.white : Colors.black,
            )),
      ),
    );
  }
}

// ── Event badges (to the right of the circle) ──

class _EventBadges extends StatelessWidget {
  final List<LineupEvent> events;
  const _EventBadges({required this.events});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final e in events) _iconFor(e),
      ],
    );
  }

  Widget _iconFor(LineupEvent event) {
    switch (event.type) {
      case LineupEventType.yellowCard:
        return Container(
          width: 7,
          height: 10,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC00),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      case LineupEventType.redCard:
        return Container(
          width: 7,
          height: 10,
          margin: const EdgeInsets.only(left: 1),
          decoration: BoxDecoration(
            color: const Color(0xFFE8000A),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      case LineupEventType.goal:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports_soccer, size: 10, color: Colors.black),
        );
      case LineupEventType.assist:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Text(
            'A',
            style: TextStyle(
              color: Colors.black,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        );
      case LineupEventType.subIn:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFF4CAF50),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_upward_rounded,
              size: 9, color: Colors.white),
        );
      case LineupEventType.subOut:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE8000A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_downward_rounded,
              size: 9, color: Colors.white),
        );
      case LineupEventType.injury:
        return Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(left: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE8000A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.add, size: 10, color: Colors.white),
        );
    }
  }
}

// ── Pitch markings (halfway line + center circle) ──

class _PitchMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final midY = size.height / 2;

    // Halfway line
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);

    // Center circle (~22% of width radius)
    canvas.drawCircle(Offset(size.width / 2, midY), size.width * 0.22, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SubstitutesAndCoach extends StatelessWidget {
  final List<Substitute> subsA;
  final List<Substitute> subsB;
  final String coachA;
  final String coachB;

  const SubstitutesAndCoach({
    super.key,
    required this.subsA,
    required this.subsB,
    required this.coachA,
    required this.coachB,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("SUBSTITUTES", style: Body2_b.style),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _SubList(subs: subsA, alignEnd: false)),
            Expanded(child: _SubList(subs: subsB, alignEnd: true)),
          ],
        ),
        const SizedBox(height: 24),
        const Text("COACH", style: Body2_b.style),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(coachA, style: Eyebrow.style),
            Text(coachB, style: Eyebrow.style),
          ],
        ),
      ],
    );
  }
}

class _SubList extends StatelessWidget {
  final List<Substitute> subs;
  final bool alignEnd;

  const _SubList({required this.subs, required this.alignEnd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: subs.map((sub) {
        final children = [
          if (!alignEnd)
            Flexible(
              child: Text(sub.name,
                  style: Eyebrow.style, overflow: TextOverflow.ellipsis),
            ),
          if (sub.subIn) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_circle_left, size: 20, color: Colors.white),
          ],
          if (sub.minute != null) ...[
            const SizedBox(width: 4),
            Text("${sub.minute}'", style: Eyebrow.style),
          ],
          if (sub.goal) ...[
            const SizedBox(width: 4),
            const Icon(Icons.sports_soccer, size: 20, color: Colors.white),
          ],
          if (alignEnd)
            Flexible(
              child: Text(sub.name,
                  style: Eyebrow.style, overflow: TextOverflow.ellipsis),
            ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment:
                alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: children,
          ),
        );
      }).toList(),
    );
  }
}
