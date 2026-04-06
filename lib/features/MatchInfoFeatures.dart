import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/matchdata.dart';


enum LineupEventType { yellowCard, redCard, goal, subIn, subOut }

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
  final String homeTeamName;
  final String awayTeamName;
  final String homeScore;
  final String awayScore;
  final String statusLabel; // "Final" or live clock e.g. "42:02"
  final String venueName;

  const MatchScoreHeader({
    super.key,
    required this.homeLogoAsset,
    required this.awayLogoAsset,
    required this.homeTeamName,
    required this.awayTeamName,
    required this.homeScore,
    required this.awayScore,
    required this.statusLabel,
    required this.venueName,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TeamBlock(logoAsset: homeLogoAsset, name: homeTeamName),
        const SizedBox(width: 20),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ScoreBox(score: homeScore),
                const SizedBox(width: 8),
                _ScoreBox(score: awayScore),
              ],
            ),
            const SizedBox(height: 16),
            Text(statusLabel, style: Body2_b.style),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.30,
              child: Container(width: 24, height: 1, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(venueName, style: Body2.style),
          ],
        ),
        const SizedBox(width: 20),
        _TeamBlock(logoAsset: awayLogoAsset, name: awayTeamName),
      ],
    );
  }
}

class _TeamBlock extends StatelessWidget {
  final String logoAsset;
  final String name;
  const _TeamBlock({required this.logoAsset, required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(logoAsset, width: 72, height: 72),
        const SizedBox(height: 8),
        Text(name, style: Body1.style),
      ],
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final String score;
  const _ScoreBox({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(score, style: Heading1.style),
    );
  }
}

class MatchEventsSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const MatchEventsSection({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: events.map((event) {
          final isHome = event['team'] == 'home';
          final player = event['player'] as String;
          final minute = event['minute'] as String;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: isHome
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const Icon(Icons.sports_soccer, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(player, style: Body1.style, overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),
                SizedBox(
                  width: 40,
                  child: Center(child: Text(minute, style: Body1.style)),
                ),
                Expanded(
                  child: !isHome
                      ? Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(player, style: Body1.style, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.sports_soccer, color: Colors.white, size: 16),
                    ],
                  )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class MatchHighlights extends StatelessWidget {
  final String imageAsset;

  const MatchHighlights({super.key, required this.imageAsset});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("HIGHLIGHTS", style: Body2_b.style),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            imageAsset,
            width: double.infinity,
            height: 194,
            fit: BoxFit.cover,
          ),
        ),
      ],
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
                  const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 40),
                  const SizedBox(width: 16),
                  Text(rating, style: Heading2.style),
                ],
              ),
              const SizedBox(height: 42),
              Text(playerName, style: Heading5.style, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Text(teamAndNumber, style: Body2.style, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}


class MomentumChart extends StatelessWidget {
  const MomentumChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text("MOMENTUM", style: Body2_b.style),
        SizedBox(height: 12),
        SizedBox(height: 100, child: Placeholder()),
      ],
    );
  }
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

  const StatBarData({
    required this.category,
    required this.homePercent,
    required this.awayPercent,
  });
}

class StatComparisonBar extends StatelessWidget {
  final StatBarData data;

  const StatComparisonBar({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.homePercent + data.awayPercent;
    final homeFlex = (data.homePercent / total * 100).round();
    final awayFlex = 100 - homeFlex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Center(child: Text(data.category.toUpperCase(), style: Body2_b.style)),
          const SizedBox(height: 6),
          Row(
            children: [
              Text("${data.homePercent.toInt()}%", style: Body2.style),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Expanded(flex: homeFlex, child: Container(height: 8, color: Colors.redAccent)),
                      Expanded(flex: awayFlex, child: Container(height: 8, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text("${data.awayPercent.toInt()}%", style: Body2.style),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LINEUP", style: Body2_b.style),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _PitchMarkingsPainter())),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 4),
                child: Column(
                  children: [
                    // Away: GK at top, attackers nearest the halfway line
                    for (int i = 0; i < awayRows.length; i++) ...[
                      _PlayerRow(
                        players: awayRows[i],
                        isHome: false,
                        onTap: (p) => onPlayerTap(context, p),
                      ),
                      if (i < awayRows.length - 1) const SizedBox(height: 12),
                    ],
                    // Gap that the center circle overlaps
                    const SizedBox(height: 56),
                    // Home: attackers nearest the halfway line, GK at bottom
                    for (int i = 0; i < homeRows.length; i++) ...[
                      _PlayerRow(
                        players: homeRows[i],
                        isHome: true,
                        onTap: (p) => onPlayerTap(context, p),
                      ),
                      if (i < homeRows.length - 1) const SizedBox(height: 12),
                    ],
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
          .map((p) => _PlayerDot(player: p, isHome: isHome, onTap: () => onTap(p)))
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _PlayerCircle(number: player.number, isHome: isHome),
              if (player.events.isNotEmpty) ...[
                const SizedBox(width: 3),
                _EventBadges(events: player.events),
              ],
            ],
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: 64,
            child: Text(
              player.name,
              style: Body2.style,
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
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isHome ? _accent : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            color: isHome ? Colors.white : Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1,
          ),
        ),
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
    final minute = events.map((e) => e.minute).whereType<int>().firstOrNull;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (final e in events) _iconFor(e),
        if (minute != null) ...[
          const SizedBox(width: 2),
          Text("$minute'", style: Body2.style),
        ],
      ],
    );
  }

  Widget _iconFor(LineupEvent event) {
    switch (event.type) {
      case LineupEventType.yellowCard:
        return Container(
          width: 9,
          height: 12,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFFCC00),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      case LineupEventType.redCard:
        return Container(
          width: 9,
          height: 12,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFE8000A),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      case LineupEventType.goal:
        return const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Icon(Icons.sports_soccer, size: 14, color: Colors.white),
        );
      case LineupEventType.subIn:
        return const Padding(
          padding: EdgeInsets.only(right: 2),
          child: Icon(Icons.swap_horiz_rounded, size: 14, color: Color(0xFF4CAF50)),
        );
      case LineupEventType.subOut:
        return Padding(
          padding: const EdgeInsets.only(right: 2),
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFE8000A),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.arrow_downward_rounded, size: 9, color: Colors.white),
          ),
        );
    }
  }
}

// ── Pitch markings (halfway line + center circle) ──

class _PitchMarkingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.18)
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
            Text(coachA, style: Body1.style),
            Text(coachB, style: Body1.style),
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
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: subs.map((sub) {
        final children = [
          if (!alignEnd)
            Flexible(
              child: Text(sub.name, style: Body1.style, overflow: TextOverflow.ellipsis),
            ),
          if (sub.subIn) ...[
            const SizedBox(width: 4),
            const Icon(Icons.arrow_circle_left, size: 20, color: Colors.white),
          ],
          if (sub.minute != null) ...[
            const SizedBox(width: 4),
            Text("${sub.minute}'", style: Body1.style),
          ],
          if (sub.goal) ...[
            const SizedBox(width: 4),
            const Icon(Icons.sports_soccer, size: 20, color: Colors.white),
          ],
          if (alignEnd)
            Flexible(
              child: Text(sub.name, style: Body1.style, overflow: TextOverflow.ellipsis),
            ),
        ];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: children,
          ),
        );
      }).toList(),
    );
  }
}