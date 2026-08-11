import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/helper.dart';

enum StandingView { standing, xgTable }

// Qualification tiers — color-coded row indicators for European spots / relegation
// Reflects 2024/25 UEFA coefficient bonus (5 UCL spots for top-2 ranked leagues
// that year: England, Italy, Germany). Adjust per season as needed.

enum QualificationTier { ucl, uel, conference, relegation }

extension QualificationTierMeta on QualificationTier {
  String get label {
    switch (this) {
      case QualificationTier.ucl:
        return 'UCL';
      case QualificationTier.uel:
        return 'UEL';
      case QualificationTier.conference:
        return 'CONF';
      case QualificationTier.relegation:
        return 'REL';
    }
  }

  Color get color {
    switch (this) {
      case QualificationTier.ucl:
        return const Color(0xFF2D8CFF); // blue
      case QualificationTier.uel:
        return const Color(0xFFFF7A3D); // orange
      case QualificationTier.conference:
        return const Color(0xFF22C55E); // green
      case QualificationTier.relegation:
        return const Color(0xFFEF4444); // red
    }
  }
}

class LeagueQualificationRules {
  final Set<int> uclPositions;
  final Set<int> uelPositions;
  final Set<int> conferencePositions;
  final Set<int> relegationPositions;

  const LeagueQualificationRules({
    this.uclPositions = const {},
    this.uelPositions = const {},
    this.conferencePositions = const {},
    this.relegationPositions = const {},
  });

  QualificationTier? tierFor(int position) {
    if (uclPositions.contains(position)) return QualificationTier.ucl;
    if (uelPositions.contains(position)) return QualificationTier.uel;
    if (conferencePositions.contains(position))
      return QualificationTier.conference;
    if (relegationPositions.contains(position))
      return QualificationTier.relegation;
    return null;
  }

  // Tiers that actually apply to this league (for legend filtering)
  List<QualificationTier> get availableTiers => [
        if (uclPositions.isNotEmpty) QualificationTier.ucl,
        if (uelPositions.isNotEmpty) QualificationTier.uel,
        if (conferencePositions.isNotEmpty) QualificationTier.conference,
        if (relegationPositions.isNotEmpty) QualificationTier.relegation,
      ];
}

// Per-league rules. Null = no coloring (e.g. UCL/Europa/cups).
const Map<int, LeagueQualificationRules> _leagueRules = {
  // Premier League (20 teams, 2024/25 — 5 UCL via coefficient bonus)
  8: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4, 5},
    uelPositions: {6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
  // La Liga (20 teams)
  82: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4},
    uelPositions: {5},
    conferencePositions: {6},
    relegationPositions: {18, 19, 20},
  ),
  // Serie A (20 teams, 2024/25 — 5 UCL via coefficient bonus)
  301: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4, 5},
    uelPositions: {6},
    conferencePositions: {7},
    relegationPositions: {18, 19, 20},
  ),
  // Bundesliga (18 teams, 2024/25 — 5 UCL via coefficient bonus)
  384: LeagueQualificationRules(
    uclPositions: {1, 2, 3, 4, 5},
    uelPositions: {6},
    conferencePositions: {7},
    relegationPositions: {17, 18},
  ),
  // Ligue 1 (18 teams)
  564: LeagueQualificationRules(
    uclPositions: {1, 2, 3},
    uelPositions: {4},
    conferencePositions: {5},
    relegationPositions: {17, 18},
  ),
};

LeagueQualificationRules? rulesForLeague(int leagueId) =>
    _leagueRules[leagueId];

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

class StandingViewToggle extends StatelessWidget {
  final StandingView selectedView;
  final List<StandingView> availableViews;
  final ValueChanged<StandingView> onChanged;

  const StandingViewToggle({
    super.key,
    required this.selectedView,
    required this.availableViews,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);

    return Container(
      key: const ValueKey('standing-view-toggle'),
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        border: Border.all(
          color: isDark ? AppPalette.lightGrey : appColors.divider,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: StandingView.values
            .map(
              (view) => Expanded(
                child: _StandingViewSegment(
                  view: view,
                  isSelected: selectedView == view,
                  isEnabled: availableViews.contains(view),
                  onTap: () => onChanged(view),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _StandingViewSegment extends StatelessWidget {
  const _StandingViewSegment({
    required this.view,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final StandingView view;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    final foreground = isSelected
        ? AppPalette.white
        : isEnabled
            ? Theme.of(context).colorScheme.onSurface
            : appColors.mutedForeground;
    final background = isSelected
        ? AppPalette.black
        : isDark
            ? AppPalette.lightGrey
            : AppPalette.white;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      child: Material(
        color: background,
        child: InkWell(
          key: ValueKey(
            'standing-view-${view == StandingView.standing ? 'standing' : 'xg-table'}',
          ),
          onTap: isEnabled ? onTap : null,
          child: Center(
            child: Text(
              view.label,
              style: Body2_b.style.copyWith(color: foreground),
            ),
          ),
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
            _buildClubColumn(context),
            Container(width: 1, color: AppColors.of(context).divider),
            Expanded(child: _buildStatsSide(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildClubColumn(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(context),
          const SizedBox(height: 24),
          ...standings.map((team) => _buildClubRow(context, team)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClubHeader(BuildContext context) {
    return Container(
      width: 146,
      color: AppColors.of(context).subtleBackground,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
      child: Text('Club', style: Body1.style),
    );
  }

  Widget _buildClubRow(BuildContext context, Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final textStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    final tier = rulesForLeague(leagueId)?.tierFor(team['rank'] as int);

    return Container(
      width: 146,
      color: AppColors.of(context).cardBackground,
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
                  GestureDetector(
                    onTap: () => context.push('/team/${team['teamId']}'),
                    child: Image.network(
                      team['logo'],
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          teamLogoFallback(team['teamId'] as int, size: 20),
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

  Widget _buildStatsSide(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                color: AppColors.of(context).subtleBackground,
                padding: const EdgeInsets.only(
                    left: 24, right: 16, top: 24, bottom: 16),
                child: Row(
                  children: [
                    _buildHeaderCell(context, 'MP'),
                    _buildHeaderCell(context, 'W'),
                    _buildHeaderCell(context, 'D'),
                    _buildHeaderCell(context, 'L'),
                    _buildHeaderCell(context, 'GF'),
                    _buildHeaderCell(context, 'GA'),
                    _buildHeaderCell(context, 'GD'),
                    _buildHeaderCell(context, 'Pts'),
                    _buildHeaderCell(context, 'Last 5', isWide: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...standings.map((team) => _buildStatRow(context, team)),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                height: 24,
                color: AppColors.of(context).cardBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final cellStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      color: AppColors.of(context).cardBackground,
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _buildStatCell(context, '${team['mp']}', style: cellStyle),
          _buildStatCell(context, '${team['w']}', style: cellStyle),
          _buildStatCell(context, '${team['d']}', style: cellStyle),
          _buildStatCell(context, '${team['l']}', style: cellStyle),
          _buildStatCell(context, '${team['gf']}', style: cellStyle),
          _buildStatCell(context, '${team['ga']}', style: cellStyle),
          _buildStatCell(
            context,
            '${(team['gf'] as int) - (team['ga'] as int)}',
            style: cellStyle,
          ),
          _buildStatCell(context, '${team['pts']}', style: cellStyle),
          _buildLastFive(context, List<String>.from(team['last5'] as List)),
        ],
      ),
    );
  }

  Widget _buildLastFive(BuildContext context, List<String> results) {
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
              color = Theme.of(context).colorScheme.onSurface;
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
            _buildClubColumn(context),
            Container(width: 1, color: AppColors.of(context).divider),
            Expanded(child: _buildStatsSide(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildClubColumn(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(context),
          const SizedBox(height: 24),
          ...standings.map((team) => _buildClubRow(context, team)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClubHeader(BuildContext context) {
    return Container(
      width: 146,
      color: AppColors.of(context).subtleBackground,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
      child: Text('Club', style: Body1.style),
    );
  }

  Widget _buildClubRow(BuildContext context, Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final textStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    final tier = rulesForLeague(leagueId)?.tierFor(team['rank'] as int);

    return Container(
      width: 146,
      color: AppColors.of(context).cardBackground,
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
                  GestureDetector(
                    onTap: () => context.push('/team/${team['teamId']}'),
                    child: Image.network(
                      team['logo'],
                      width: 20,
                      height: 20,
                      errorBuilder: (_, __, ___) =>
                          teamLogoFallback(team['teamId'] as int, size: 20),
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

  Widget _buildStatsSide(BuildContext context) {
    return Container(
      color: AppColors.of(context).cardBackground,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        controller: horizontalScrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.only(
                topRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                color: AppColors.of(context).subtleBackground,
                padding: const EdgeInsets.only(
                    left: 24, right: 16, top: 24, bottom: 16),
                child: Row(
                  children: [
                    _buildHeaderCell(context, 'MP'),
                    _buildHeaderCell(context, 'xG'),
                    _buildHeaderCell(context, 'xGA'),
                    _buildHeaderCell(context, 'xPts'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...standings.map((team) => _buildStatRow(context, team)),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomRight:
                    isScrolledToEnd ? const Radius.circular(16) : Radius.zero,
              ),
              child: Container(
                height: 24,
                color: AppColors.of(context).cardBackground,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, Map<String, dynamic> team) {
    final isCurrentTeam = team['teamId'] == currentTeamId;
    final cellStyle = Body2.style.copyWith(
      color: isCurrentTeam
          ? Theme.of(context).colorScheme.onSurface
          : AppColors.of(context).mutedForeground,
      fontWeight: isCurrentTeam ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      color: AppColors.of(context).cardBackground,
      padding: const EdgeInsets.only(left: 24, right: 16),
      child: Row(
        children: [
          _buildStatCell(context, '${team['mp']}', style: cellStyle),
          _buildStatCell(context, _formatXg(team['xg']), style: cellStyle),
          _buildStatCell(context, _formatXg(team['xga']), style: cellStyle),
          _buildStatCell(
            context,
            _formatXpts(team['xpts']),
            style: cellStyle,
          ),
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

Widget _buildHeaderCell(BuildContext context, String title,
    {bool isWide = false}) {
  return Container(
    width: isWide ? 100 : 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: AppColors.of(context).subtleBackground,
    child: Text(title, style: Body2.style),
  );
}

Widget _buildStatCell(BuildContext context, String text,
    {bool isWide = false, TextStyle? style}) {
  return Container(
    width: isWide ? 100 : 44,
    height: 44,
    padding: const EdgeInsets.only(right: 8),
    alignment: Alignment.center,
    color: AppColors.of(context).cardBackground,
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
