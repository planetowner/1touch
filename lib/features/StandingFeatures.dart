import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/helper.dart';

enum StandingView { standing, xgTable }

// Qualification tiers — color-coded row indicators for European spots / relegation
// Reflects 2024/25 UEFA coefficient bonus (5 UCL spots for top-2 ranked leagues
// that year: England, Italy, Germany). Adjust per season as needed.

enum QualificationTier { ucl, uel, conference, relegation }

extension QualificationTierMeta on QualificationTier {
  String get label {
    switch (this) {
      case QualificationTier.ucl:        return 'UCL';
      case QualificationTier.uel:        return 'UEL';
      case QualificationTier.conference: return 'CONF';
      case QualificationTier.relegation: return 'REL';
    }
  }

  Color get color {
    switch (this) {
      case QualificationTier.ucl:        return const Color(0xFF2D8CFF); // blue
      case QualificationTier.uel:        return const Color(0xFFFF7A3D); // orange
      case QualificationTier.conference: return const Color(0xFF22C55E); // green
      case QualificationTier.relegation: return const Color(0xFFEF4444); // red
    }
  }
}

class LeagueQualificationRules {
  final Set<int> uclPositions;
  final Set<int> uelPositions;
  final Set<int> conferencePositions;
  final Set<int> relegationPositions;

  const LeagueQualificationRules({
    this.uclPositions        = const {},
    this.uelPositions        = const {},
    this.conferencePositions = const {},
    this.relegationPositions = const {},
  });

  QualificationTier? tierFor(int position) {
    if (uclPositions.contains(position))        return QualificationTier.ucl;
    if (uelPositions.contains(position))        return QualificationTier.uel;
    if (conferencePositions.contains(position)) return QualificationTier.conference;
    if (relegationPositions.contains(position)) return QualificationTier.relegation;
    return null;
  }

  // Tiers that actually apply to this league (for legend filtering)
  List<QualificationTier> get availableTiers => [
    if (uclPositions.isNotEmpty)        QualificationTier.ucl,
    if (uelPositions.isNotEmpty)        QualificationTier.uel,
    if (conferencePositions.isNotEmpty) QualificationTier.conference,
    if (relegationPositions.isNotEmpty) QualificationTier.relegation,
  ];
}

// Per-league rules. Null = no coloring (e.g. UCL/Europa/cups).
const Map<int, LeagueQualificationRules> _leagueRules = {
  // Premier League (20 teams, 2024/25 — 5 UCL via coefficient bonus)
  8: LeagueQualificationRules(
    uclPositions:        {1, 2, 3, 4, 5},
    uelPositions:        {6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
  // La Liga (20 teams)
  82: LeagueQualificationRules(
    uclPositions:        {1, 2, 3, 4},
    uelPositions:        {5},
    conferencePositions: {6},
    relegationPositions: {18, 19, 20},
  ),
  // Serie A (20 teams, 2024/25 — 5 UCL via coefficient bonus)
  301: LeagueQualificationRules(
    uclPositions:        {1, 2, 3, 4, 5},
    uelPositions:        {6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
  // Bundesliga (18 teams, 2024/25 — 5 UCL via coefficient bonus)
  384: LeagueQualificationRules(
    uclPositions:        {1, 2, 3, 4, 5},
    uelPositions:        {6},
    conferencePositions: {7},
    relegationPositions: {17, 18},
  ),
  // Ligue 1 (18 teams)
  564: LeagueQualificationRules(
    uclPositions:        {1, 2, 3},
    uelPositions:        {4},
    conferencePositions: {5},
    relegationPositions: {17, 18},
  ),
};

LeagueQualificationRules? rulesForLeague(int leagueId) => _leagueRules[leagueId];

extension StandingViewLabel on StandingView {
  String get label {
    switch (this) {
      case StandingView.standing:
        return 'STANDING';
      case StandingView.xgTable:
        return 'XG TABLE';
    }
  }
}

class StandingViewSelector extends StatelessWidget {
  final StandingView selectedView;
  final bool isOpen;
  final VoidCallback onToggle;

  const StandingViewSelector({
    super.key,
    required this.selectedView,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return _ViewSelectorButton(
      selectedView: selectedView,
      isOpen: isOpen,
      onToggle: onToggle,
    );
  }
}

class _ViewSelectorButton extends StatelessWidget {
  final StandingView selectedView;
  final bool isOpen;
  final VoidCallback onToggle;

  const _ViewSelectorButton({
    required this.selectedView,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(selectedView.label, style: Body2_b.style),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: AnimatedRotation(
              turns: isOpen ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StandingViewOptions extends StatelessWidget {
  final StandingView selectedView;
  final List<StandingView> availableViews;
  final ValueChanged<StandingView> onChanged;

  const StandingViewOptions({
    super.key,
    required this.selectedView,
    required this.availableViews,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 132,
        decoration: BoxDecoration(
          color: const Color(0xFF272828),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: availableViews
              .map<Widget>((view) => _buildViewItem(view))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildViewItem(StandingView view) {
    final selected = selectedView == view;

    return GestureDetector(
      onTap: () => onChanged(view),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                view.label,
                style: selected ? Body2_b.style : Body2.style,
              ),
            ),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 16)
            else
              const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }
}

class StandingTable extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
  final int? currentTeamId;
  final int leagueId;
  final ScrollController horizontalScrollController;
  final bool isScrolledToEnd;

  const StandingTable({
    super.key,
    required this.standings,
    required this.currentTeamId,
    required this.leagueId,
    required this.horizontalScrollController,
    required this.isScrolledToEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClubColumn(),
            Container(width: 1, color: Colors.black),
            Expanded(child: _buildStatsSide()),
          ],
        ),
      ),
    );
  }

  Widget _buildClubColumn() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(),
          const SizedBox(height: 24),
          ...standings.map(_buildClubRow),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClubHeader() {
    return Container(
      width: 146,
      color: const Color(0xFF3D3D3D),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
      child: Text('Club', style: Body1.style),
    );
  }

  Widget _buildClubRow(Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final textStyle = Body2.style.copyWith(
      color: isCurrentTeam ? Colors.white : Colors.white54,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    final tier = rulesForLeague(leagueId)?.tierFor(team['rank'] as int);

    return Container(
      width: 146,
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // ── Tier indicator bar (UCL/UEL/CONF/REL) ──────────────
          Container(
            width: 4,
            height: 44,
            color: tier?.color ?? Colors.transparent,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${team['rank']}',
                      style: textStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.network(
                    team['logo'],
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => Image.asset(
                      randomTeamLogo(),
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${team['team']}',
                      style: textStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSide() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                color: const Color(0xFF3D3D3D),
                padding: const EdgeInsets.only(left: 24, right: 16, top: 24, bottom: 16),
                child: Row(
                  children: [
                    _buildHeaderCell('MP'),
                    _buildHeaderCell('W'),
                    _buildHeaderCell('D'),
                    _buildHeaderCell('L'),
                    _buildHeaderCell('GF'),
                    _buildHeaderCell('GA'),
                    _buildHeaderCell('GD'),
                    _buildHeaderCell('Pts'),
                    _buildHeaderCell('Last 5', isWide: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...standings.map(_buildStatRow),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomRight: isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                height: 24,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final cellStyle = Body2.style.copyWith(
      color: isCurrentTeam ? Colors.white : Colors.white54,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _buildStatCell('${team['mp']}', style: cellStyle),
          _buildStatCell('${team['w']}', style: cellStyle),
          _buildStatCell('${team['d']}', style: cellStyle),
          _buildStatCell('${team['l']}', style: cellStyle),
          _buildStatCell('${team['gf']}', style: cellStyle),
          _buildStatCell('${team['ga']}', style: cellStyle),
          _buildStatCell('${(team['gf'] as int) - (team['ga'] as int)}', style: cellStyle),
          _buildStatCell('${team['pts']}', style: cellStyle),
          _buildLastFive(List<String>.from(team['last5'] as List)),
        ],
      ),
    );
  }

  Widget _buildLastFive(List<String> results) {
    return SizedBox(
      width: 100,
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: results.map((result) {
          Color color;
          switch (result) {
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
          return Icon(Icons.check_circle, size: 19, color: color);
        }).toList(),
      ),
    );
  }
}

class XgTable extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
  final int? currentTeamId;
  final int leagueId;
  final ScrollController horizontalScrollController;
  final bool isScrolledToEnd;

  const XgTable({
    super.key,
    required this.standings,
    required this.currentTeamId,
    required this.leagueId,
    required this.horizontalScrollController,
    required this.isScrolledToEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildClubColumn(),
            Container(width: 1, color: Colors.black),
            Expanded(child: _buildStatsSide()),
          ],
        ),
      ),
    );
  }

  Widget _buildClubColumn() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(),
          const SizedBox(height: 24),
          ...standings.map(_buildClubRow),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClubHeader() {
    return Container(
      width: 146,
      color: const Color(0xFF3D3D3D),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
      child: Text('Club', style: Body1.style),
    );
  }

  Widget _buildClubRow(Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final textStyle = Body2.style.copyWith(
      color: isCurrentTeam ? Colors.white : Colors.white54,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    final tier = rulesForLeague(leagueId)?.tierFor(team['rank'] as int);

    return Container(
      width: 146,
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          // ── Tier indicator bar (UCL/UEL/CONF/REL) ──────────────
          Container(
            width: 4,
            height: 44,
            color: tier?.color ?? Colors.transparent,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${team['rank']}',
                      style: textStyle,
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Image.network(
                    team['logo'],
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => Image.asset(
                      randomTeamLogo(),
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${team['team']}',
                      style: textStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSide() {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight: isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                color: const Color(0xFF3D3D3D),
                padding: const EdgeInsets.only(left: 24, right: 16, top: 24, bottom: 16),
                child: Row(
                  children: [
                    _buildHeaderCell('MP'),
                    _buildHeaderCell('xG'),
                    _buildHeaderCell('xGA'),
                    _buildHeaderCell('xPts'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...standings.map(_buildStatRow),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomRight: isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                height: 24,
                color: const Color(0xFF1E1E1E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final cellStyle = Body2.style.copyWith(
      color: isCurrentTeam ? Colors.white : Colors.white54,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      color: const Color(0xFF1E1E1E),
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _buildStatCell('${team['mp']}', style: cellStyle),
          _buildStatCell(_formatXg(team['xg']),   style: cellStyle),
          _buildStatCell(_formatXg(team['xga']),  style: cellStyle),
          _buildStatCell(_formatXpts(team['xpts']), style: cellStyle),
        ],
      ),
    );
  }

  // xG / xGA: 1 decimal place; backend stores 3 but UI shows 1 for readability
  String _formatXg(dynamic value) {
    if (value is num) return value.toStringAsFixed(1);
    return '—';
  }

  // xPts: 1 decimal place to preserve sort meaning
  String _formatXpts(dynamic value) {
    if (value is num) return value.toStringAsFixed(1);
    return '—';
  }
}

Widget _buildHeaderCell(String title, {bool isWide = false}) {
  return Container(
    width: isWide ? 100 : 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: const Color(0xFF3D3D3D),
    child: Text(title, style: Body2.style),
  );
}

Widget _buildStatCell(String text, {bool isWide = false, TextStyle? style}) {
  return Container(
    width: isWide ? 100 : 44,
    height: 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: const Color(0xFF1E1E1E),
    child: Text(text, style: style ?? Body2.style),
  );
}

// Legend showing what each color bar means for the current league.
// Only shows tiers that actually apply (e.g. no relegation for cups).
// Returns SizedBox.shrink() if league has no qualification rules.


class StandingsLegend extends StatelessWidget {
  final int leagueId;

  const StandingsLegend({super.key, required this.leagueId});

  @override
  Widget build(BuildContext context) {
    final rules = rulesForLeague(leagueId);
    if (rules == null) return const SizedBox.shrink();

    final tiers = rules.availableTiers;
    if (tiers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 20,
        runSpacing: 8,
        children: tiers.map((tier) => _LegendItem(tier: tier)).toList(),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final QualificationTier tier;

  const _LegendItem({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: tier.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(tier.label, style: Body2_b.style),
      ],
    );
  }
}