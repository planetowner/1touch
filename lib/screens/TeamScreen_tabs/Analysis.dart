import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/competitions/mock/season_catalog.dart';
import 'package:onetouch/data/teams/mock/best_eleven_catalog.dart';
import 'package:onetouch/data/teams/mock/team_analysis_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_form_comparison.dart';
import 'package:onetouch/data/teams/mock/team_form_catalog.dart';
import 'package:onetouch/models/best_eleven.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';

class AnalysisTab extends StatelessWidget {
  final Map<String, dynamic>? team;

  const AnalysisTab({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final rawTeam = team?['raw'];
    final rawFormData = rawTeam is Map<String, dynamic>
        ? rawTeam['current_form_comparison']
        : null;
    final serverFormComparison = TeamFormComparison.tryFromJson(
      team?['current_form_comparison'] ?? rawFormData,
    );
    final teamId = team?['id'] as int? ?? 83;
    final currentFormComparison =
        serverFormComparison ?? mockTeamFormComparison(teamId);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttributesSection(team: team),
          ProbabilitySection(),
          BestElevenSection(team: team),
          CurrentFormSection(data: currentFormComparison, team: team),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTRIBUTES — radar chart comparing the current team to a chosen reference
// (same team, different season).
// ─────────────────────────────────────────────────────────────────────────────

class AttributesSection extends StatefulWidget {
  final Map<String, dynamic>? team;
  const AttributesSection({super.key, required this.team});

  @override
  State<AttributesSection> createState() => _AttributesSectionState();
}

class _AttributesSectionState extends State<AttributesSection> {
  TeamAttributeScores? _myScores;
  TeamAttributeScores? _comparisonScores;
  List<TeamAttributeScores> _comparisonOptions = const [];

  int get _teamId => widget.team?['id'] as int? ?? 83; // default Barcelona

  @override
  void initState() {
    super.initState();
    _loadAttributes();
  }

  @override
  void didUpdateWidget(AttributesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This section's State is reused across team switches (the Team-tab
    // branch stays alive in the bottom-nav shell), so reload instead of
    // only loading once in initState.
    if (widget.team?['id'] != oldWidget.team?['id']) {
      setState(_loadAttributes);
    }
  }

  void _loadAttributes() {
    final all = teamAttributesByTeam(_teamId);
    if (all.isEmpty) return;

    // MY TEAM is always the current season — find it via the isCurrent flag,
    // never assume "newest seasonId". Falls back to newest if no current match.
    final currentSeasonIds =
    mockSeasons.where((s) => s.isCurrent).map((s) => s.seasonId).toSet();
    _myScores = all.firstWhere(
          (a) => currentSeasonIds.contains(a.seasonId),
      orElse: () => all.first,
    );

    // Everything except the current season is a comparison candidate.
    _comparisonOptions =
        all.where((a) => a.seasonId != _myScores!.seasonId).toList();
    _comparisonScores =
    _comparisonOptions.isNotEmpty ? _comparisonOptions.first : null;
  }

  @override
  Widget build(BuildContext context) {
    if (_myScores == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Text('No attribute data available',
            style: TextStyle(color: Colors.white54)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + comparison picker ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ATTRIBUTES', style: Body2_b.style),
              if (_comparisonOptions.isNotEmpty) _buildComparisonPill(),
            ],
          ),
          const SizedBox(height: 16),

          // ── Radar chart container ────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF272828),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildRadarChart(),
          ),

          // ── Legend ───────────────────────────────────────────────────
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legendDot(const Color(0xFFE8434A), 'MY TEAM'),
              if (_comparisonScores != null) ...[
                const SizedBox(width: 20),
                _legendDot(
                  Colors.white,
                  '${_comparisonScores!.seasonLabel} '
                      '${mockTeamById(_comparisonScores!.teamId).name.toUpperCase()}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Comparison picker pill (season-only for now) ────────────────────────

  Widget _buildComparisonPill() {
    final team = mockTeamById(_teamId);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _comparisonScores?.seasonId,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF3D3D3D),
          style: Body2_b.style,
          onChanged: (seasonId) {
            if (seasonId == null) return;
            setState(() {
              _comparisonScores = _comparisonOptions
                  .firstWhere((s) => s.seasonId == seasonId);
            });
          },
          selectedItemBuilder: (_) => _comparisonOptions
              .map((s) => _pillContent(s.seasonLabel, team))
              .toList(),
          items: _comparisonOptions
              .map(
                (s) => DropdownMenuItem(
              value: s.seasonId,
              child: Text('${s.seasonLabel}  ${team.shortCode ?? team.name}',
                  style: Body2_b.style),
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  Widget _pillContent(String seasonLabel, Team team) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(seasonLabel, style: Body2_b.style),
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: Colors.white24),
        const SizedBox(width: 8),
        Image.network(
          team.imagePath ?? '',
          width: 16,
          height: 16,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.shield, size: 16, color: Colors.white54),
        ),
        const SizedBox(width: 6),
        Text(team.shortCode ?? team.name, style: Body2_b.style),
      ],
    );
  }

  // ── Radar chart ─────────────────────────────────────────────────────────

  // Fixed frame for the radar's scale. fl_chart derives the chart's center and
  // radius from the min/max value across ALL datasets, so without a pinned
  // range MY TEAM's polygon would rescale (and visibly change shape) every time
  // a different comparison season is picked. Anchoring the floor/ceiling keeps
  // MY TEAM identical no matter what it's compared to. Attribute values are
  // clamped to 5-95, so 0..100 gives clean headroom and aligns with tickCount.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;

  Widget _buildRadarChart() {
    return SizedBox(
      height: 260,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 1),
          radarBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 1),
          tickBorderData: BorderSide(color: Colors.white.withValues(alpha: 0.30), width: 1),
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 0),

          getTitle: (index, _) => RadarChartTitle(
            text: teamAttributeLabels[index],
            angle: 0,
          ),
          titleTextStyle: Eyebrow.style,
          titlePositionPercentageOffset: 0.15,

          dataSets: [
            // MY TEAM — red
            RadarDataSet(
              fillColor: const Color(0xFFE8434A).withValues(alpha: 0.3),
              borderColor: const Color(0xFFE8434A),
              borderWidth: 2,
              entryRadius: 3,
              dataEntries: _myScores!.radarValues
                  .map((v) => RadarEntry(value: v))
                  .toList(),
            ),
            // Comparison — white outline
            if (_comparisonScores != null)
              RadarDataSet(
                fillColor: Colors.white.withValues(alpha: 0.1),
                borderColor: Colors.white.withValues(alpha: 0.85),
                borderWidth: 2,
                entryRadius: 3,
                dataEntries: _comparisonScores!.radarValues
                    .map((v) => RadarEntry(value: v))
                    .toList(),
              ),
            // Invisible anchor — pins the scale to a fixed [floor, ceil] range
            // so the visible polygons never rescale between comparisons.
            _scaleAnchorDataSet(),
          ],
        ),
      ),
    );
  }

  // Fully transparent dataset carrying one floor value and the rest at the
  // ceiling, so both minEntry and maxEntry across the chart stay constant.
  RadarDataSet _scaleAnchorDataSet() {
    final count = _myScores!.radarValues.length;
    return RadarDataSet(
      fillColor: Colors.transparent,
      borderColor: Colors.transparent,
      borderWidth: 0,
      entryRadius: 0,
      dataEntries: List.generate(
        count,
        (i) => RadarEntry(value: i == 0 ? _radarFloor : _radarCeil),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Body2_b.style),
      ],
    );
  }
}

class BestElevenSection extends StatefulWidget {
  final Map<String, dynamic>? team;
  const BestElevenSection({super.key, required this.team});

  @override
  State<BestElevenSection> createState() => _BestElevenSectionState();
}

class _BestElevenSectionState extends State<BestElevenSection> {
  // Recommended-formation options with confidence %, eventually populated by
  // a backend model. The lineup shown below is re-fetched per selection —
  // mock data currently only has one real formation per team, so picking an
  // option with no matching data shows the empty state.
  static const List<String> formations = [
    "4-2-3-1 (90%)",
    "4-3-3 (88%)",
    "3-5-2 (82%)",
  ];

  late String selectedFormation;
  List<BestElevenPlayer> _players = [];

  int get _teamId => widget.team?['id'] as int? ?? 83; // default Barcelona

  String _formationKey(String option) => option.split(' ').first;

  @override
  void initState() {
    super.initState();
    _resetForTeam();
  }

  @override
  void didUpdateWidget(BestElevenSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This section's State is reused across team switches (the Team-tab
    // branch stays alive in the bottom-nav shell), so reload instead of
    // only loading once in initState.
    if (widget.team?['id'] != oldWidget.team?['id']) {
      setState(_resetForTeam);
    }
  }

  // Defaults the dropdown to whichever option matches the team's actual
  // mocked formation, so it doesn't open on an empty state.
  void _resetForTeam() {
    final actualFormation = bestElevenByTeam(_teamId).firstOrNull?.formation;
    selectedFormation = formations.firstWhere(
      (f) => _formationKey(f) == actualFormation,
      orElse: () => formations.first,
    );
    _loadPlayers();
  }

  void _loadPlayers() {
    _players = bestElevenByTeam(_teamId, formation: _formationKey(selectedFormation));
  }

  void _changeFormation(String formation) {
    setState(() {
      selectedFormation = formation;
      _loadPlayers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BEST ELEVEN", style: Body2_b.style),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                decoration: BoxDecoration(
                  color: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedFormation,
                    icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                    dropdownColor: const Color(0xFF3D3D3D),
                    style: Body2_b.style,
                    onChanged: (val) {
                      if (val != null) _changeFormation(val);
                    },
                    items: formations.map((f) {
                      return DropdownMenuItem(
                        value: f,
                        child: Text(f),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No lineup data for this formation yet',
                style: Body2.style,
              ),
            )
          else
            BestElevenPitch(players: _players),
        ],
      ),
    );
  }
}

class CurrentFormSection extends StatefulWidget {
  final TeamFormComparison? data;
  final Map<String, dynamic>? team;

  const CurrentFormSection({
    super.key,
    required this.data,
    required this.team,
  });

  @override
  State<CurrentFormSection> createState() => _CurrentFormSectionState();
}

class _CurrentFormSectionState extends State<CurrentFormSection> {
  int _selectedComparisonIndex = 0;

  TeamFormSeries? get _comparison {
    final comparisons = widget.data?.comparisons ?? const [];
    if (comparisons.isEmpty) return null;
    return comparisons[_selectedComparisonIndex.clamp(0, comparisons.length - 1)];
  }

  @override
  void didUpdateWidget(CurrentFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _selectedComparisonIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("CURRENT FORM", style: Body2_b.style),
              if (_comparison != null) _buildComparisonPicker(),
            ],
          ),
          const SizedBox(height: 16),
          if (widget.data == null || widget.data!.current.points.isEmpty)
            _buildEmptyState()
          else
            _buildChart(),
          if (widget.data != null && widget.data!.current.points.isNotEmpty)
            _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildComparisonPicker() {
    final comparisons = widget.data!.comparisons;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedComparisonIndex,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF3D3D3D),
          onChanged: (index) {
            if (index != null) {
              setState(() => _selectedComparisonIndex = index);
            }
          },
          selectedItemBuilder: (_) => comparisons.map((series) {
            return _comparisonLabel(series);
          }).toList(),
          items: List.generate(
            comparisons.length,
            (index) => DropdownMenuItem(
              value: index,
              child: _comparisonLabel(comparisons[index]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _comparisonLabel(TeamFormSeries series) {
    final logo = widget.team?['logo'] as String? ??
        widget.team?['image_path'] as String? ??
        '';
    final teamCode = widget.team?['short_code'] as String? ??
        widget.team?['name'] as String? ??
        '';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(series.seasonLabel, style: Body2_b.style),
        const SizedBox(width: 8),
        Container(width: 1, height: 16, color: Colors.white24),
        const SizedBox(width: 8),
        Image.network(
          logo,
          width: 18,
          height: 18,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.shield, size: 18, color: Colors.white54),
        ),
        const SizedBox(width: 6),
        Text(teamCode, style: Body2_b.style),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        'Current form data is not available yet',
        style: Body2.style.copyWith(color: Colors.white54),
      ),
    );
  }

  Widget _buildChart() {
    final current = widget.data!.current;
    final comparison = _comparison;
    final allPoints = [
      ...current.points,
      ...?comparison?.points,
    ];
    final maxRound = math.max(
      2,
      allPoints.map((point) => point.round).reduce(math.max),
    );
    final highestPoints = allPoints.map((point) => point.points).reduce(math.max);
    final maxPoints = math.max(5, ((highestPoints + 4) ~/ 5) * 5).toDouble();

    return Container(
      height: 346,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                RotatedBox(
                  quarterTurns: 3,
                  child: Text('POINTS', style: Body2_b.style),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      minX: 1,
                      maxX: maxRound.toDouble(),
                      minY: 0,
                      maxY: maxPoints,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxPoints / 8,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: Colors.white24,
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Colors.black,
                          getTooltipItems: (spots) => spots
                              .map(
                                (spot) => LineTooltipItem(
                                  'Round ${spot.x.toInt()}  ${spot.y.toInt()} Pts',
                                  Body2_b.style,
                                ),
                              )
                              .toList(),
                        ),
                        getTouchedSpotIndicator: (bar, indexes) => indexes
                            .map(
                              (_) => TouchedSpotIndicatorData(
                                FlLine(
                                  color: Colors.white70,
                                  strokeWidth: 1,
                                  dashArray: [6, 6],
                                ),
                                FlDotData(
                                  getDotPainter: (_, __, ___, ____) =>
                                      FlDotCirclePainter(
                                    radius: 4,
                                    color: bar.color ?? Colors.white,
                                    strokeWidth: 0,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      lineBarsData: [
                        _formLine(current, const Color(0xFFFF525D)),
                        if (comparison != null)
                          _formLine(comparison, Colors.white),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text('ROUND', style: Body2_b.style),
          ),
        ],
      ),
    );
  }

  LineChartBarData _formLine(TeamFormSeries series, Color color) {
    return LineChartBarData(
      spots: series.points
          .map((point) => FlSpot(point.round.toDouble(), point.points.toDouble()))
          .toList(),
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _buildLegend() {
    final comparison = _comparison;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _legendItem(const Color(0xFFFF525D), 'CURRENT'),
          if (comparison != null) ...[
            const SizedBox(width: 20),
            _legendItem(
              Colors.white,
              '${comparison.seasonLabel} '
              '${(widget.team?['name'] as String? ?? '').toUpperCase()}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Body2_b.style),
      ],
    );
  }
}

class ProbabilitySection extends StatelessWidget {
  const ProbabilitySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PROBABILITY", style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _probabilityBox(
                  title: "Chances to win\nUCL Trophy",
                  value: 16,
                  delta: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _probabilityBox(
                  title: "Chances to win\nLEAGUE Trophy",
                  value: 32,
                  delta: 2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _probabilityBox({
    required String title,
    required int value,
    required int delta,
  }) {
    final bool isUp = delta >= 0;
    final IconData arrow = isUp ? Icons.arrow_drop_up : Icons.arrow_drop_down;
    final Color arrowColor = isUp ? Colors.blueAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Body1.style),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                "$value",
                style: Heading1.style,
              ),
              Text(
                "%",
                style: Heading4.style,
              ),
              Spacer(),
              Row(
                children: [
                  Icon(arrow, color: arrowColor, size: 24),
                  Text(
                    "$delta",
                    style: Heading5.style,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
