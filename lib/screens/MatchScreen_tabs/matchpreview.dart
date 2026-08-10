import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/features/helper.dart';
import 'package:fl_chart/fl_chart.dart';

class _StandingRow {
  final int pos;
  final String name;
  final int teamId;
  final String? logoUrl;
  final String mp;
  final String w;
  final String d;
  final String l;
  final bool highlight;

  const _StandingRow({
    required this.pos,
    required this.name,
    required this.teamId,
    required this.logoUrl,
    required this.mp,
    required this.w,
    required this.d,
    required this.l,
    required this.highlight,
  });
}

class MatchPreviewTab extends StatefulWidget {
  final Fixture fixture;
  const MatchPreviewTab({super.key, required this.fixture});

  @override
  State<MatchPreviewTab> createState() => _MatchPreviewTabState();
}

class _MatchPreviewTabState extends State<MatchPreviewTab> {
  // Hardcoded for UI demo
  final int userBalance = 1200;

  void _openBettingModal() {
    final homeTeam =
        teamRepository.findByIdOrUnknown(widget.fixture.homeTeamId);
    final awayTeam =
        teamRepository.findByIdOrUnknown(widget.fixture.awayTeamId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Using the widget from the new file
        return BettingFlowModal(
          userBalance: userBalance,
          homeTeam: homeTeam,
          awayTeam: awayTeam,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam =
        teamRepository.findByIdOrUnknown(widget.fixture.homeTeamId);
    final awayTeam =
        teamRepository.findByIdOrUnknown(widget.fixture.awayTeamId);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildHeader(),
          const SizedBox(height: 48),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: Text(
              "BET",
              style: Body2_b.style,
            ),
          ),
          const SizedBox(height: 16),

          // Using the extracted widget from the new file
          MatchBettingSection(
            userBalance: userBalance,
            onPlaceBet: _openBettingModal,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
          ),

          const SizedBox(height: 48),
          _buildRadarChart(),
          const SizedBox(height: 48),
          _buildLatestH2H(),
          const SizedBox(height: 48),
          _buildStandingTable(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final home = teamRepository.findByIdOrUnknown(widget.fixture.homeTeamId);
    final away = teamRepository.findByIdOrUnknown(widget.fixture.awayTeamId);
    final dt = DateTime.parse(widget.fixture.startingAt).toLocal();
    final date = DateFormat('EEE, MMM d').format(dt);
    final time = DateFormat('h:mm a').format(dt);

    return Row(
      children: [
        Expanded(
          child: _buildTeamBlock(
            home.shortCode ?? home.name,
            home.imagePath ?? '',
            home.teamId,
          ),
        ),
        SizedBox(
          width: 104,
          child: Column(
            children: [
              Text(date, style: Body2.style, textAlign: TextAlign.center),
              Text(time, style: Body2.style),
              const SizedBox(height: 8),
              Opacity(
                opacity: 0.30,
                child: Container(
                  width: 24,
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(width: 1, color: foreground),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Venue Name', style: Body2.style),
            ],
          ),
        ),
        Expanded(
          child: _buildTeamBlock(
            away.shortCode ?? away.name,
            away.imagePath ?? '',
            away.teamId,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamBlock(String name, String logoPath, int teamId) {
    return Column(
      children: [
        GestureDetector(
          // The match screen sits on the root navigator (see main.dart's
          // '/match/:matchId'), but '/team/:id' belongs to the bottom-nav
          // shell's own navigator — push() would land there invisibly,
          // behind this screen. go() replaces the location so it surfaces.
          onTap: () => context.go('/team/$teamId'),
          child: Image.network(
            logoPath,
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 72),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Body1.style,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildRadarChart() {
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        SizedBox(
          height: 260,
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              tickCount: 4,

              // Grid rings
              gridBorderData: BorderSide(
                color: foreground.withValues(alpha: 0.30),
                width: 1,
              ),
              // Outermost ring
              radarBorderData: BorderSide(
                color: foreground.withValues(alpha: 0.30),
                width: 1,
              ),
              // Tick rings (same as grid)
              tickBorderData: BorderSide(
                color: foreground.withValues(alpha: 0.30),
                width: 1,
              ),

              // Hide tick value labels on each ring
              ticksTextStyle: const TextStyle(
                color: Colors.transparent,
                fontSize: 0,
              ),

              // Axis labels
              getTitle: (index, angle) {
                const labels = [
                  'Attack',
                  'Progression',
                  'Pressure',
                  'Dominance',
                  'Defense',
                  'Possession',
                ];
                return RadarChartTitle(
                  text: labels[index],
                  angle: 0, // keep all labels upright
                );
              },
              titleTextStyle: Eyebrow.style.copyWith(color: foreground),
              titlePositionPercentageOffset: 0.15,

              dataSets: [
                // Home team
                RadarDataSet(
                  fillColor: const Color(0xFFE8434A).withValues(alpha: 0.3),
                  borderColor: const Color(0xFFE8434A),
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: const [
                    RadarEntry(value: 85), // Attack
                    RadarEntry(value: 75), // Progression
                    RadarEntry(value: 55), // Pressure
                    RadarEntry(value: 70), // Dominance
                    RadarEntry(value: 80), // Defense
                    RadarEntry(value: 65), // Possession
                  ],
                ),
                // Away team
                RadarDataSet(
                  fillColor: foreground.withValues(alpha: 0.1),
                  borderColor: foreground.withValues(alpha: 0.85),
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: const [
                    RadarEntry(value: 55),
                    RadarEntry(value: 60),
                    RadarEntry(value: 75),
                    RadarEntry(value: 50),
                    RadarEntry(value: 60),
                    RadarEntry(value: 72),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildLegendDot(
                const Color(0xFFE8434A),
                teamRepository
                    .findByIdOrUnknown(widget.fixture.homeTeamId)
                    .name
                    .toUpperCase(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildLegendDot(
                foreground,
                teamRepository
                    .findByIdOrUnknown(widget.fixture.awayTeamId)
                    .name
                    .toUpperCase(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: Body2_b.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLatestH2H() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeId = widget.fixture.homeTeamId;
    final awayId = widget.fixture.awayTeamId;

    // Most recent past fixture between the two teams
    final h2h = mockFixtures
        .where((f) =>
            f.status == FixtureStatus.past &&
            ((f.homeTeamId == homeId && f.awayTeamId == awayId) ||
                (f.homeTeamId == awayId && f.awayTeamId == homeId)))
        .lastOrNull;

    if (h2h == null) return const SizedBox.shrink();

    final home = teamRepository.findByIdOrUnknown(h2h.homeTeamId);
    final away = teamRepository.findByIdOrUnknown(h2h.awayTeamId);
    final dt = DateTime.parse(h2h.startingAt).toLocal();
    final date = DateFormat('EEE, MMM d').format(dt);
    final time = DateFormat('h:mm a').format(dt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("LATEST H2H", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('match-preview-h2h-card'),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.lightGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  _buildSimpleTeamCol(home.shortCode ?? home.name,
                      home.imagePath ?? '', home.teamId),
                  const SizedBox(width: 16),
                  _buildScoreBox(h2h.homeScore?.toString() ?? '-'),
                ],
              ),
              Column(
                children: [
                  Text(date, style: Body2.style),
                  Text(time, style: Body2.style),
                ],
              ),
              Row(
                children: [
                  _buildScoreBox(h2h.awayScore?.toString() ?? '-'),
                  const SizedBox(width: 16),
                  _buildSimpleTeamCol(away.shortCode ?? away.name,
                      away.imagePath ?? '', away.teamId),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTeamCol(String name, String asset, int teamId) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => context.go('/team/$teamId'),
          child: Image.network(
            asset,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 48),
          ),
        ),
        const SizedBox(height: 4),
        Text(name, style: Body2.style),
      ],
    );
  }

  Widget _buildScoreBox(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
          color: isDark ? Colors.black : AppPalette.lightGreyBox,
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: Heading3.style.copyWith(color: foreground)),
    );
  }

  Widget _buildStandingTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final league = mockCompetitionById(widget.fixture.competitionId);
    final standings = standingsByCompetition(widget.fixture.competitionId);
    if (standings.isEmpty) return const SizedBox.shrink();

    final matchTeamIds = {
      widget.fixture.homeTeamId,
      widget.fixture.awayTeamId,
    };
    final leaders = standings.take(5).toList();
    final leaderIds = leaders.map((standing) => standing.teamId).toSet();
    final featured = standings
        .where((standing) =>
            matchTeamIds.contains(standing.teamId) &&
            !leaderIds.contains(standing.teamId))
        .toList();
    final visibleStandings = [...leaders, ...featured];
    final dividerIndex = featured.isEmpty ? -1 : leaders.length;
    final rows = visibleStandings.map((standing) {
      final team = teamRepository.findByIdOrUnknown(standing.teamId);
      return _StandingRow(
        pos: standing.position,
        name: team.shortCode ?? team.name,
        teamId: team.teamId,
        logoUrl: team.imagePath,
        mp: standing.matchesPlayed.toString(),
        w: standing.won.toString(),
        d: standing.draw.toString(),
        l: standing.lost.toString(),
        highlight: matchTeamIds.contains(team.teamId),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("STANDING", style: Body2_b.style),
        const SizedBox(height: 16),
        // ── HEADER BOX: rounded top corners only ──
        Container(
          key: const ValueKey('match-preview-standing-header'),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // League logo + name
              Row(
                children: [
                  Image.network(
                    league.imagePath ?? '',
                    width: 24,
                    height: 24,
                    errorBuilder: (_, __, ___) =>
                        competitionLogoFallback(league.competitionId, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    league.name,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Column labels
              Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('#',
                        style: TextStyle(
                            color: appColors.mutedForeground, fontSize: 13)),
                  ),
                  Expanded(
                    child: Text('Club',
                        style: TextStyle(
                            color: appColors.mutedForeground, fontSize: 13)),
                  ),
                  ..._colLabel('MP'),
                  ..._colLabel('W'),
                  ..._colLabel('D'),
                  ..._colLabel('L'),
                ],
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: appColors.divider),
            ],
          ),
        ),
        // ── BODY BOX: rounded bottom corners only ──
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            children: List.generate(rows.length, (i) {
              final row = rows[i];
              return Column(
                children: [
                  if (i == dividerIndex)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: Text(
                          '• • •',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  _buildStandingRowWidget(row),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  List<Widget> _colLabel(String text) => [
        SizedBox(
          width: 32,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.of(context).mutedForeground,
              fontSize: 12,
            ),
          ),
        ),
      ];

  Widget _buildStandingRowWidget(_StandingRow row) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;
    final textStyle = TextStyle(
      color: foreground,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );
    final mutedStyle = TextStyle(
      color: row.highlight ? foreground : mutedForeground,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 28,
            child: Text(
              '${row.pos}',
              style: mutedStyle,
            ),
          ),
          // Logo + name
          Expanded(
            child: Row(
              children: [
                if (row.logoUrl != null && row.logoUrl!.isNotEmpty)
                  Image.network(
                    row.logoUrl!,
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) =>
                        teamLogoFallback(row.teamId, size: 20),
                  )
                else
                  teamLogoFallback(row.teamId, size: 20),
                const SizedBox(width: 8),
                Text(row.name, style: textStyle),
              ],
            ),
          ),
          // MP W D L
          for (final val in [row.mp, row.w, row.d, row.l])
            SizedBox(
              width: 32,
              child: Text(
                val,
                textAlign: TextAlign.center,
                style: mutedStyle,
              ),
            ),
        ],
      ),
    );
  }
}
