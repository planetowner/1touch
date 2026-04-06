import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'standing.dart'; // StandingRowOut

enum StandingDisplayMode {
  /// Compact — used in MatchPreviewTab.
  compact,

  /// Full — used in StandingTab / OverviewTab.
  full,
}

class StandingEntry {
  final int rank;
  final String teamName;
  final String teamFullName;

  /// Asset path (local) or URL (from API). Use Image.asset for mock data,
  /// Image.network once connected to the backend.
  final String logoAsset;

  final int mp;
  final int w;
  final int d;
  final int l;
  final int gf;
  final int ga;
  final int pts;

  /// Last 5 results, most recent last — 'W', 'D', or 'L'
  final List<String> lastFive;

  const StandingEntry({
    required this.rank,
    required this.teamName,
    required this.teamFullName,
    required this.logoAsset,
    required this.mp,
    required this.w,
    required this.d,
    required this.l,
    required this.gf,
    required this.ga,
    required this.pts,
    this.lastFive = const [],
  });

  int get gd => gf - ga;

  /// Bridges the API model [StandingRowOut] into a [StandingEntry].
  ///
  /// Note: [logoAsset] is set to the URL from the API ([StandingRowOut.teamLogo]).
  /// Switch Image.asset → Image.network in [StandingWidget] when going live.
  factory StandingEntry.fromStandingRowOut(StandingRowOut row) {
    return StandingEntry(
      rank: row.position,
      teamName: row.teamName ?? '',
      teamFullName: row.teamName ?? '',
      logoAsset: row.teamLogo ?? '',
      mp: row.matchesPlayed,
      w: row.won,
      d: row.draw,
      l: row.lost,
      gf: row.goalsFor,
      ga: row.goalsAgainst,
      pts: row.points,
      lastFive: row.last5Form,
    );
  }
}

// ─────────────────────────────────────────────
// Config for compact mode
// ─────────────────────────────────────────────

class StandingCompactConfig {
  final List<int> highlightedRanks;
  final int? topRowCount;

  const StandingCompactConfig({
    required this.highlightedRanks,
    this.topRowCount = 5,
  });
}

// ─────────────────────────────────────────────
// Widget — unchanged
// ─────────────────────────────────────────────

class StandingWidget extends StatefulWidget {
  final List<StandingEntry> entries;
  final StandingDisplayMode mode;
  final String leagueName;
  final String leagueLogoAsset;
  final StandingCompactConfig? compactConfig;

  const StandingWidget({
    super.key,
    required this.entries,
    required this.mode,
    this.leagueName = 'La Liga',
    this.leagueLogoAsset = 'LeagueLogos/laliga.png',
    this.compactConfig,
  }) : assert(
  mode != StandingDisplayMode.compact || compactConfig != null,
  'compactConfig is required when mode is compact',
  );

  @override
  State<StandingWidget> createState() => _StandingWidgetState();
}

class _StandingWidgetState extends State<StandingWidget> {
  bool _isScrolledToEnd = false;
  final ScrollController _hScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _hScroll.addListener(() {
      final atEnd = _hScroll.offset >= _hScroll.position.maxScrollExtent - 4;
      if (_isScrolledToEnd != atEnd) {
        setState(() => _isScrolledToEnd = atEnd);
      }
    });
  }

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.mode == StandingDisplayMode.compact
        ? _buildCompact()
        : _buildFull();
  }

  // ─────────────────────────────────────────
  // COMPACT MODE
  // ─────────────────────────────────────────

  Widget _buildCompact() {
    final cfg = widget.compactConfig!;
    final all = widget.entries;

    final int cut = cfg.topRowCount ?? all.length;
    final topRows = all.take(cut).toList();
    final overflowRows = all
        .skip(cut)
        .where((e) => cfg.highlightedRanks.contains(e.rank))
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                widget.leagueLogoAsset,
                width: 20,
                height: 20,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.sports_soccer,
                  color: Color(0xFFE8434A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.leagueName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(width: 28),
              const Expanded(
                child: Text('Club',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              ..._compactColLabel('MP'),
              ..._compactColLabel('W'),
              ..._compactColLabel('D'),
              ..._compactColLabel('L'),
            ],
          ),
          const SizedBox(height: 8),
          ...topRows.map(
                (e) => _compactRow(e, cfg.highlightedRanks.contains(e.rank)),
          ),
          if (overflowRows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text('...',
                    style: TextStyle(color: Colors.grey, fontSize: 14)),
              ),
            ),
            ...overflowRows.map((e) => _compactRow(e, true)),
          ],
        ],
      ),
    );
  }

  List<Widget> _compactColLabel(String text) => [
    SizedBox(
      width: 32,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    ),
  ];

  Widget _compactRow(StandingEntry e, bool highlight) {
    final base = TextStyle(
      color: highlight ? Colors.white : Colors.grey,
      fontSize: 13,
      fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text('${e.rank}', style: base)),
          Expanded(
            child: Row(
              children: [
                _teamLogo(e.logoAsset, 20),
                const SizedBox(width: 8),
                Text(e.teamName, style: base),
              ],
            ),
          ),
          for (final val in [e.mp, e.w, e.d, e.l])
            SizedBox(
              width: 32,
              child: Text('$val', textAlign: TextAlign.center, style: base),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // FULL MODE
  // ─────────────────────────────────────────

  Widget _buildFull() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: const Color(0xFF1E1E1E),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 146,
                  color: const Color(0xFF3D3D3D),
                  padding: const EdgeInsets.only(
                      left: 24, right: 24, top: 24, bottom: 16),
                  alignment: Alignment.centerLeft,
                  child: Text('Club', style: Body2.style),
                ),
                const SizedBox(height: 24),
                ...widget.entries.map((e) => _fullLeftRow(e)),
                const SizedBox(height: 24),
              ],
            ),
          ),
          Container(width: 1, color: Colors.black),
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _hScroll,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topRight: _isScrolledToEnd
                            ? const Radius.circular(16)
                            : Radius.zero,
                      ),
                      child: Container(
                        color: const Color(0xFF3D3D3D),
                        padding: const EdgeInsets.only(
                            left: 24, right: 16, top: 24, bottom: 16),
                        child: Row(
                          children: [
                            _fullHeaderCell('MP'),
                            _fullHeaderCell('W'),
                            _fullHeaderCell('D'),
                            _fullHeaderCell('L'),
                            _fullHeaderCell('GF'),
                            _fullHeaderCell('GA'),
                            _fullHeaderCell('GD'),
                            _fullHeaderCell('Pts'),
                            _fullHeaderCell('Last 5', isWide: true),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ...widget.entries.map((e) => _fullRightRow(e)),
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomRight: _isScrolledToEnd
                            ? const Radius.circular(16)
                            : Radius.zero,
                      ),
                      child: Container(height: 24, color: const Color(0xFF1E1E1E)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fullLeftRow(StandingEntry e) {
    return Container(
      width: 146,
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child:
            Text('${e.rank}', style: Body2.style, textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          _teamLogo(e.logoAsset, 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(e.teamFullName,
                style: Body2.style, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _fullRightRow(StandingEntry e) {
    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _fullStatCell('${e.mp}'),
          _fullStatCell('${e.w}'),
          _fullStatCell('${e.d}'),
          _fullStatCell('${e.l}'),
          _fullStatCell('${e.gf}'),
          _fullStatCell('${e.ga}'),
          _fullStatCell('${e.gd}'),
          _fullStatCell('${e.pts}'),
          _fullLastFive(e.lastFive),
        ],
      ),
    );
  }

  Widget _fullHeaderCell(String title, {bool isWide = false}) {
    return Container(
      width: isWide ? 100 : 32,
      padding: const EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      color: const Color(0xFF3D3D3D),
      child: Text(title, style: Body2.style),
    );
  }

  Widget _fullStatCell(String text) {
    return Container(
      width: 32,
      padding: const EdgeInsets.only(right: 8),
      alignment: Alignment.center,
      color: const Color(0xFF1E1E1E),
      child: Text(text, style: Body2.style),
    );
  }

  Widget _fullLastFive(List<String> results) {
    return SizedBox(
      width: 100,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: results.map((r) {
          Color color;
          switch (r) {
            case 'W':
              color = Colors.blue;
              break;
            case 'D':
              color = Colors.grey;
              break;
            case 'L':
              color = Colors.red;
              break;
            default:
              color = Colors.white;
          }
          return Icon(Icons.circle, size: 10, color: color);
        }).toList(),
      ),
    );
  }


  Widget _teamLogo(String asset, double size) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white24,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}