import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository.dart';
import 'package:onetouch/data/match_analysis/match_analysis_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/fixture_detail.dart';
import 'package:onetouch/models/match_tactical_analysis.dart';
import 'package:onetouch/features/match_info/match_info_features.dart';

import 'match_event_view_data.dart';

class AnalysisTab extends StatefulWidget {
  final Fixture fixture;
  final FixtureDetail? detail;
  final MatchAnalysisRepository? repository;

  const AnalysisTab({
    super.key,
    required this.fixture,
    this.detail,
    this.repository,
  });

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  bool showHome = true;
  bool get isLive => false;
  MatchTacticalAnalysis? _analysis;
  MatchShotMap? _shotMap;
  bool _isLoading = false;
  Object? _loadError;
  int _requestId = 0;

  MatchAnalysisRepository get _repository =>
      widget.repository ?? matchAnalysisRepository;

  MatchTeamTacticalAnalysis? get _homeAnalysis => _analysis?.home;
  MatchTeamTacticalAnalysis? get _awayAnalysis => _analysis?.away;
  MatchTeamTacticalAnalysis? get _selectedAnalysis =>
      showHome ? _homeAnalysis : _awayAnalysis;

  @override
  void initState() {
    super.initState();
    _startLoad(updateState: false);
  }

  @override
  void didUpdateWidget(covariant AnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fixture.fixtureId != widget.fixture.fixtureId ||
        oldWidget.repository != widget.repository) {
      showHome = true;
      _startLoad();
    }
  }

  void _startLoad({bool updateState = true}) {
    final fixtureId = widget.fixture.fixtureId;
    final requestId = ++_requestId;
    MatchAnalysisRepository? repository;
    Object? repositoryError;
    try {
      repository = _repository;
    } on Object catch (error) {
      repositoryError = error;
    }
    final cachedAnalysis = repository?.cachedAnalysisForFixture(fixtureId);
    final cachedShotMap = repository?.cachedShotMapForFixture(fixtureId);

    void prepare() {
      _analysis = cachedAnalysis;
      _shotMap = cachedShotMap;
      _isLoading = repositoryError == null &&
          (cachedAnalysis == null || cachedShotMap == null);
      _loadError = repositoryError;
    }

    if (updateState) {
      setState(prepare);
    } else {
      prepare();
    }
    if (repository != null) {
      unawaited(_load(fixtureId, requestId, repository));
    }
  }

  Future<void> _load(
    int fixtureId,
    int requestId,
    MatchAnalysisRepository repository,
  ) async {
    try {
      final results = await Future.wait<Object>([
        repository.loadAnalysis(fixtureId),
        repository.loadShotMap(fixtureId),
      ]);
      if (!mounted ||
          requestId != _requestId ||
          fixtureId != widget.fixture.fixtureId) {
        return;
      }
      setState(() {
        _analysis = results[0] as MatchTacticalAnalysis;
        _shotMap = results[1] as MatchShotMap;
        _isLoading = false;
        _loadError = null;
      });
    } on Object catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final matchEvents = fixtureSummaryEventRows(
      events: widget.detail?.events ?? const <FixtureEvent>[],
      homeTeamId: widget.fixture.homeTeamId,
      awayTeamId: widget.fixture.awayTeamId,
    );
    final tacticalAvailable = _analysis?.available == true;
    final shotMapAvailable = _shotMap?.available == true;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildScoreHeader(),
          if (matchEvents.isNotEmpty)
            MatchEventsSection(
              key: const ValueKey('match-analysis-events'),
              events: matchEvents,
            ),
          if (widget.detail?.expectedGoals case final expectedGoals?)
            _buildXGSection(expectedGoals),
          if (_isLoading) ...[
            const SizedBox(height: 48),
            const Center(child: CircularProgressIndicator()),
          ] else if (_loadError != null) ...[
            const SizedBox(height: 48),
            _buildLoadError(),
          ] else ...[
            if (tacticalAvailable || shotMapAvailable) ...[
              const SizedBox(height: 48),
              _buildAttackBlock(),
            ],
            if (_possessionRows().isNotEmpty) ...[
              const SizedBox(height: 48),
              _buildPossessionBlock(),
            ],
            if (tacticalAvailable) ...[
              const SizedBox(height: 48),
              _buildProgressionBlock(),
              const SizedBox(height: 48),
              _buildDefensiveActivityBlock(),
            ],
            if (!tacticalAvailable && !shotMapAvailable) ...[
              const SizedBox(height: 48),
              _buildUnavailableNotice(),
            ],
          ],
          if (_defenseRows().isNotEmpty ||
              widget.detail?.expectedGoals != null ||
              widget.fixture.homeScore != null ||
              widget.fixture.awayScore != null) ...[
            const SizedBox(height: 48),
            _buildDefenseBlock(),
          ],
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildLoadError() => Center(
        child: Column(
          children: [
            const Text('Match analysis could not be loaded.'),
            TextButton(onPressed: _startLoad, child: const Text('Retry')),
          ],
        ),
      );

  Widget _buildUnavailableNotice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppPalette.darkGrey
              : AppPalette.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          'Tactical analysis is unavailable for this match.',
          textAlign: TextAlign.center,
          style: Body1.style,
        ),
      );

  Widget _buildScoreHeader() {
    final home = fixtureHomeTeam(widget.fixture, teamRepository);
    final away = fixtureAwayTeam(widget.fixture, teamRepository);

    return MatchScoreHeader(
      homeLogoAsset: home.imagePath ?? '',
      awayLogoAsset: away.imagePath ?? '',
      homeTeamId: home.teamId,
      awayTeamId: away.teamId,
      homeTeamName: home.name,
      awayTeamName: away.name,
      homeScore: widget.fixture.homeScore?.toString() ?? '#',
      awayScore: widget.fixture.awayScore?.toString() ?? '#',
      statusLabel: isLive ? '42:02' : 'Final',
      roundLabel: widget.fixture.roundName,
    );
  }

  Widget _buildXGSection(FixtureExpectedGoals expectedGoals) {
    return SizedBox(
      key: const ValueKey('match-analysis-xg'),
      width: double.infinity,
      child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: const Color(0xFFFF5C5C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    expectedGoals.homeXg.toStringAsFixed(2),
                    style: Body2_b.style.copyWith(color: AppPalette.white),
                  ),
                ],
              ),
            ),
            Text('XG', textAlign: TextAlign.center, style: Body2_b.style),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias,
              decoration: ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(expectedGoals.awayXg.toStringAsFixed(2),
                      style: Body2_b.style.copyWith(color: Colors.black)),
                ],
              ),
            ),
          ]),
    );
  }

  static const Color _homeColor = Color(0xFFFF5C5C);

  String get _homeCode {
    final team = fixtureHomeTeam(widget.fixture, teamRepository);
    return team.shortCode?.trim().isNotEmpty == true
        ? team.shortCode!
        : _shortName(team.name);
  }

  String get _awayCode {
    final team = fixtureAwayTeam(widget.fixture, teamRepository);
    return team.shortCode?.trim().isNotEmpty == true
        ? team.shortCode!
        : _shortName(team.name);
  }

  String _shortName(String name) =>
      name.length <= 8 ? name : name.substring(0, 8);

  List<MatchShot> get _selectedShots => (_shotMap?.shots ?? const <MatchShot>[])
      .where(
        (shot) =>
            shot.teamId ==
            (showHome ? widget.fixture.homeTeamId : widget.fixture.awayTeamId),
      )
      .toList(growable: false);

  List<ShotMapPlot> get _selectedShotPlots => [
        for (final shot in _selectedShots)
          ShotMapPlot(
            start: _halfPitchPoint(shot.start, isHome: showHome),
            end: _halfPitchPoint(shot.end, isHome: showHome),
            isGoal: shot.result.toLowerCase() == 'goal',
          ),
      ];

  Offset _halfPitchPoint(TacticalPitchPoint point, {required bool isHome}) {
    final depth = isHome ? (point.x - 50) / 50 : (50 - point.x) / 50;
    return Offset(
      (point.y / 100).clamp(0.0, 1.0),
      depth.clamp(0.0, 1.0),
    );
  }

  Widget _buildAttackBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final homeShots = _shotMap?.homeCount;
    final awayShots = _shotMap?.awayCount;
    final homeGoals = _goalCount(widget.fixture.homeTeamId);
    final awayGoals = _goalCount(widget.fixture.awayTeamId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("ATTACK", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('match-analysis-attack-card'),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTeamToggle(),
                const SizedBox(height: 24),
                if (_shotMap?.available == true) ...[
                  ShotMapDiagram(
                    shots: _selectedShotPlots,
                    color: showHome ? _homeColor : foreground,
                    lineColor: foreground.withValues(alpha: 0.30),
                  ),
                  const SizedBox(height: 24),
                  _buildStatRow('Goals', homeGoals, awayGoals),
                  _buildStatRow('Shots on Target', homeShots, awayShots),
                ],
                if (_analysis?.available == true) ...[
                  _buildStatRow(
                    'Key Passes',
                    _homeAnalysis?.attack.keyPasses,
                    _awayAnalysis?.attack.keyPasses,
                  ),
                  _buildStatRow(
                    'Passes into Final Third',
                    _homeAnalysis?.attack.completedPassesIntoFinalThird,
                    _awayAnalysis?.attack.completedPassesIntoFinalThird,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPossessionBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = _possessionRows();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("POSSESSION", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildTeamToggle(),
                const SizedBox(height: 24),
                for (final row in rows)
                  if (row.label == 'Ball Possession')
                    _buildPossessionBar(row.home, row.away)
                  else
                    _buildStatRow(
                      row.label,
                      row.home,
                      row.away,
                      suffix: row.isPercent ? '%' : '',
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPossessionBar(num home, num away) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = home + away;
    final fraction = total <= 0 ? 0.5 : (home / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              key: const ValueKey('match-possession-bar'),
              height: 36,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    key: const ValueKey('match-possession-away-fill'),
                    color: isDark
                        ? AppPalette.white
                        : AppPalette.lightModeDarkGrey,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: const ValueKey('match-possession-home-fill'),
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: const ColoredBox(color: Color(0xFFFF5C5C)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatNumber(home, suffix: '%'),
                          style: Heading4.style.copyWith(
                            color: isDark && fraction != 0
                                ? AppPalette.white
                                : AppPalette.black,
                          ),
                        ),
                        Text(
                          _formatNumber(away, suffix: '%'),
                          style: Heading4.style.copyWith(color: Colors.black),
                        ),
                      ],
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

  Widget _buildProgressionBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedAnalysis?.progression;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PROGRESSION", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildTeamToggle(),
              const SizedBox(height: 24),
              ProgressionDiagram(
                lanePercents: _channelPercentages(selected),
                rightToLeft: !showHome,
                color: showHome ? _homeColor : Colors.white,
                labelColor: showHome ? Colors.white : Colors.black,
              ),
              const SizedBox(height: 24),
              _buildStatRow(
                'Completed Passes',
                _homeAnalysis?.progression.completedPasses,
                _awayAnalysis?.progression.completedPasses,
              ),
              _buildStatRow(
                'Progressive Passes',
                _homeAnalysis?.progression.progressivePasses,
                _awayAnalysis?.progression.progressivePasses,
              ),
              _buildStatRow(
                'Passes into Final Third',
                _homeAnalysis?.attack.completedPassesIntoFinalThird,
                _awayAnalysis?.attack.completedPassesIntoFinalThird,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefensiveActivityBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final selected = _selectedAnalysis?.defensiveActivity;
    final events = [
      for (final action in selected?.actions ?? const <TacticalPitchPoint>[])
        Offset(action.x / 100, action.y / 100),
    ];
    final average = selected?.averageRegainX;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('PRESSURE', style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              _buildTeamToggle(),
              const SizedBox(height: 24),
              DefensiveActivityDiagram(
                events: events,
                bands: average == null ? const [] : [average / 100],
                lineColor: foreground.withValues(alpha: 0.30),
                dotColor: foreground,
              ),
              const SizedBox(height: 24),
              _buildStatRow(
                'Recoveries',
                _homeAnalysis?.defensiveActivity.recoveries,
                _awayAnalysis?.defensiveActivity.recoveries,
              ),
              _buildStatRow(
                'High Regains',
                _homeAnalysis?.defensiveActivity.highRegains,
                _awayAnalysis?.defensiveActivity.highRegains,
              ),
              _buildStatRow(
                'Average Regain Height',
                _homeAnalysis?.defensiveActivity.averageRegainHeightMetres,
                _awayAnalysis?.defensiveActivity.averageRegainHeightMetres,
                suffix: 'm',
              ),
              _buildStatRow(
                'Opponent Half',
                _homeAnalysis?.defensiveActivity.opponentHalfPercentage,
                _awayAnalysis?.defensiveActivity.opponentHalfPercentage,
                suffix: '%',
              ),
              if (selected?.complete == false) ...[
                const SizedBox(height: 8),
                Text(
                  'Position data incomplete (${selected?.missingPositionCount ?? 0} missing)',
                  style: Body2.style.copyWith(
                    color: AppColors.of(context).mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTeamToggle() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final selectedSurface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final unselectedSurface =
        isDark ? AppPalette.black : AppPalette.lightModeDarkGrey;
    final selectedForeground = isDark ? AppPalette.white : AppPalette.black;

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showHome = true),
            child: Container(
              key: const ValueKey('match-analysis-home-toggle'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: showHome ? selectedSurface : unselectedSurface,
                border: Border.all(
                  color: isDark
                      ? AppPalette.lightGrey
                      : AppColors.of(context).divider,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _homeCode,
                style: Body2_b.style.copyWith(
                  color: showHome ? selectedForeground : foreground,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => showHome = false),
            child: Container(
              key: const ValueKey('match-analysis-away-toggle'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: !showHome ? selectedSurface : unselectedSurface,
                border: Border.all(
                  color: isDark
                      ? AppPalette.lightGrey
                      : AppColors.of(context).divider,
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _awayCode,
                style: Body2_b.style.copyWith(
                  color: !showHome ? selectedForeground : foreground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    num? home,
    num? away, {
    String suffix = '',
  }) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 40,
            child: Text(
              _formatNumber(home, suffix: suffix),
              style: Heading5.style.copyWith(
                color: showHome ? foreground : mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              label,
              style: Body1.style,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              _formatNumber(away, suffix: suffix),
              style: Heading5.style.copyWith(
                color: !showHome ? foreground : mutedForeground,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefenseBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rows = _defenseRows();
    final expectedGoals = widget.detail?.expectedGoals;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("DEFENSE", style: Body2_b.style),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                if (widget.fixture.homeScore != null ||
                    widget.fixture.awayScore != null) ...[
                  _statBoxRow(
                    leftValue: _formatNumber(widget.fixture.awayScore),
                    label: 'GA',
                    rightValue: _formatNumber(widget.fixture.homeScore),
                  ),
                ],
                if (expectedGoals != null) ...[
                  if (widget.fixture.homeScore != null ||
                      widget.fixture.awayScore != null)
                    const SizedBox(height: 16),
                  _statBoxRow(
                    leftValue: _formatNumber(expectedGoals.homeXga),
                    label: 'xGA',
                    rightValue: _formatNumber(expectedGoals.awayXga),
                  ),
                ],
                if (rows.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  for (final row in rows)
                    _buildStatRow(row.label, row.home, row.away),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _goalCount(int teamId) => (_shotMap?.shots ?? const <MatchShot>[])
      .where(
        (shot) => shot.teamId == teamId && shot.result.toLowerCase() == 'goal',
      )
      .length;

  List<double> _channelPercentages(MatchProgressionMetrics? progression) {
    if (progression == null) return const [0, 0, 0];
    final byChannel = {
      for (final channel in progression.channels)
        channel.channel: channel.percentage ?? 0,
    };
    return [
      byChannel['left'] ?? 0,
      byChannel['center'] ?? 0,
      byChannel['right'] ?? 0,
    ];
  }

  List<({String label, num home, num away, bool isPercent})> _possessionRows() {
    const definitions = [
      (code: 'ball-possession', label: 'Ball Possession', isPercent: true),
      (
        code: 'successful-passes-percentage',
        label: 'Pass Accuracy',
        isPercent: true,
      ),
      (code: 'touches', label: 'Touches', isPercent: false),
    ];
    return [
      for (final definition in definitions)
        if (_pairedStatistic(definition.code)
            case final ({double home, double away}) pair)
          (
            label: definition.label,
            home: pair.home,
            away: pair.away,
            isPercent: definition.isPercent,
          ),
    ];
  }

  List<({String label, num home, num away})> _defenseRows() {
    const definitions = [
      (code: 'tackles-won', label: 'Tackles Won'),
      (code: 'interceptions', label: 'Interceptions'),
      (code: 'blocked-shots', label: 'Blocks'),
      (code: 'duels-won', label: 'Duels Won'),
      (code: 'clearances', label: 'Clearances'),
    ];
    return [
      for (final definition in definitions)
        if (_pairedStatistic(definition.code)
            case final ({double home, double away}) pair)
          (label: definition.label, home: pair.home, away: pair.away),
    ];
  }

  ({double home, double away})? _pairedStatistic(String code) {
    final values = <int, double>{};
    for (final stat
        in widget.detail?.statistics ?? const <FixtureStatistic>[]) {
      if (stat.statCode == code) values[stat.teamId] = stat.value;
    }
    final home = values[widget.fixture.homeTeamId];
    final away = values[widget.fixture.awayTeamId];
    if (home == null || away == null) return null;
    return (home: home, away: away);
  }

  String _formatNumber(num? value, {String suffix = ''}) {
    if (value == null) return '—';
    final number = value.toDouble();
    final text = number == number.roundToDouble()
        ? number.toInt().toString()
        : number
            .toStringAsFixed(2)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
    return '$text$suffix';
  }

  Widget _statBoxRow({
    required String leftValue,
    required String label,
    required String rightValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left stat box (e.g. 2)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF5C5C),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            leftValue,
            style: Heading4.style.copyWith(color: Colors.white),
          ),
        ),

        // Center label (e.g. GA)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          child: Text(
            label,
            style: Body2_b.style,
          ),
        ),

        // Right stat box (e.g. 1)
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          alignment: Alignment.topRight,
          decoration: BoxDecoration(
            color: isDark ? AppPalette.white : AppPalette.lightModeDarkGrey,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            rightValue,
            style: Heading4.style.copyWith(color: Colors.black),
          ),
        ),
      ],
    );
  }
}

// Tactical diagram painters use normalized 0..1 coordinates so they scale
// with the available card width.

Paint _pitchLinePaint(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1;

void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dashWidth = 4.0;
  const dashSpace = 4.0;
  final totalLength = (end - start).distance;
  if (totalLength == 0) return;
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

class ShotMapPlot {
  const ShotMapPlot({
    required this.start,
    required this.end,
    required this.isGoal,
  });

  final Offset start;
  final Offset end;
  final bool isGoal;
}

// Half-pitch shot map: goal along the bottom edge.
class ShotMapDiagram extends StatelessWidget {
  final List<ShotMapPlot> shots;
  final Color color;
  final Color lineColor;
  const ShotMapDiagram({
    super.key,
    required this.shots,
    required this.color,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.2,
      child: CustomPaint(painter: _ShotMapPainter(shots, color, lineColor)),
    );
  }
}

class _ShotMapPainter extends CustomPainter {
  final List<ShotMapPlot> shots;
  final Color color;
  final Color lineColor;
  const _ShotMapPainter(this.shots, this.color, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final line = _pitchLinePaint(lineColor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);

    // Penalty box + 6-yard box, open at the goal line (bottom edge).
    final boxW = size.width * 0.62;
    final boxH = size.height * 0.40;
    canvas.drawRect(
      Rect.fromLTWH((size.width - boxW) / 2, size.height - boxH, boxW, boxH),
      line,
    );
    final smallW = size.width * 0.30;
    final smallH = size.height * 0.16;
    canvas.drawRect(
      Rect.fromLTWH(
          (size.width - smallW) / 2, size.height - smallH, smallW, smallH),
      line,
    );
    // Penalty arc ("the D") — circle centered on the penalty spot, drawing
    // only the slice that pokes above the box edge so its ends sit exactly
    // on the box line (real-pitch proportions: spot 11m/16.5m deep, r 9.15m).
    final spot = Offset(size.width / 2, size.height - boxH * 2 / 3);
    final dRadius = boxH * 0.555;
    canvas.drawArc(
      Rect.fromCircle(center: spot, radius: dRadius),
      math.pi + 0.6435,
      math.pi - 1.287,
      false,
      line,
    );
    // Center-circle arc poking in from the halfway line at the top.
    canvas.drawArc(
      Rect.fromCircle(
          center: Offset(size.width / 2, 0), radius: size.width * 0.3),
      0,
      math.pi,
      false,
      line,
    );

    final dashPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    final dotPaint = Paint()..color = color;
    final goalPaint = Paint()..color = const Color(0xFFFF5C5C);

    for (final shot in shots) {
      final start = Offset(
        shot.start.dx * size.width,
        shot.start.dy * size.height,
      );
      final end = Offset(
        shot.end.dx * size.width,
        shot.end.dy * size.height,
      );
      _drawDashedLine(canvas, start, end, dashPaint);
      canvas.drawCircle(
        start,
        shot.isGoal ? 5 : 4,
        shot.isGoal ? goalPaint : dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShotMapPainter oldDelegate) =>
      oldDelegate.shots != shots ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor;
}

// Channel progression: three gradient arrows with labels near their tips.
class ProgressionDiagram extends StatelessWidget {
  final bool rightToLeft;
  final List<double> lanePercents; // [left, center, right], 0..100
  final Color color;
  final Color labelColor;
  const ProgressionDiagram({
    super.key,
    this.rightToLeft = false,
    required this.lanePercents,
    required this.color,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 594 / 320,
      child: CustomPaint(
        painter: _ProgressionPainter(
          lanePercents,
          color,
          labelColor,
          Theme.of(context).colorScheme.onSurface,
          rightToLeft,
        ),
      ),
    );
  }
}

class _ProgressionPainter extends CustomPainter {
  final bool rightToLeft;
  final List<double> lanePercents;
  final Color color;
  final Color labelColor;
  final Color lineColor;
  const _ProgressionPainter(this.lanePercents, this.color, this.labelColor,
      this.lineColor, this.rightToLeft);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(
        size.width * (rightToLeft ? 114 : 48) / 594, size.height * 28 / 320);
    _paintArrows(canvas, Size(size.width * 432 / 594, size.height * 264 / 320));
    canvas.restore();

    final line = _pitchLinePaint(lineColor);
    final pitch = (Offset.zero & size).deflate(line.strokeWidth / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitch, const Radius.circular(5)),
      line,
    );
    canvas.drawLine(Offset(size.width / 2, pitch.top),
        Offset(size.width / 2, pitch.bottom), line);
    final radius = size.height * 0.175;
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), radius, line);

    final boxWidth = size.width * 78 / 594;
    final boxTop = size.height * 0.20;
    final boxBottom = size.height * 0.80;
    final corner = size.width * 0.012;
    for (final rightSide in [false, true]) {
      canvas.save();
      if (rightSide) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      final box = Path()
        ..moveTo(pitch.left, boxTop)
        ..lineTo(boxWidth - corner, boxTop)
        ..quadraticBezierTo(boxWidth, boxTop, boxWidth, boxTop + corner)
        ..lineTo(boxWidth, boxBottom - corner)
        ..quadraticBezierTo(boxWidth, boxBottom, boxWidth - corner, boxBottom)
        ..lineTo(pitch.left, boxBottom);
      canvas.drawPath(box, line);
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(boxWidth, 0, size.width, size.height));
      canvas.drawCircle(
          Offset(size.width * 60 / 594, size.height / 2), radius, line);
      canvas.restore();
      canvas.restore();
    }
  }

  void _paintArrows(Canvas canvas, Size size) {
    final values =
        lanePercents.take(3).map((v) => v.clamp(0.0, 100.0)).toList();
    final maximum =
        values.fold<double>(0, (largest, v) => math.max(largest, v));
    final laneHeight = size.height / 3;
    final headWidth = size.width * 0.10;
    for (var i = 0; i < values.length; i++) {
      final midY = laneHeight * (i + 0.5);
      // A minimum shaft width keeps even small percentages legible.
      final relative = maximum == 0 ? 0.0 : values[i] / maximum;
      final tip = size.width * (0.64 + 0.36 * relative);
      final shoulder = tip - headWidth;
      final shaftHalf = laneHeight * 0.32;
      final headHalf = laneHeight * 0.49;
      final path = Path()
        ..moveTo(0, midY - shaftHalf)
        ..lineTo(shoulder, midY - shaftHalf)
        ..lineTo(shoulder, midY - headHalf)
        ..lineTo(tip, midY)
        ..lineTo(shoulder, midY + headHalf)
        ..lineTo(shoulder, midY + shaftHalf)
        ..lineTo(0, midY + shaftHalf)
        ..close();
      final bounds = Rect.fromLTWH(0, midY - headHalf, tip, headHalf * 2);
      canvas.save();
      if (rightToLeft) {
        canvas.translate(size.width, 0);
        canvas.scale(-1, 1);
      }
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [color.withValues(alpha: 0), color, color],
            stops: const [0, 0.35, 1],
          ).createShader(bounds),
      );
      canvas.restore();
      final label = TextPainter(
        text: TextSpan(
          text: '${lanePercents[i].round()}%',
          style: Heading4.style.copyWith(
            color: labelColor,
            fontSize: size.width * 0.075,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(
          canvas,
          Offset(
            rightToLeft
                ? size.width - shoulder + size.width * 0.02
                : shoulder - size.width * 0.02 - label.width,
            midY - label.height / 2,
          ));
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressionPainter oldDelegate) =>
      oldDelegate.rightToLeft != rightToLeft ||
      oldDelegate.lanePercents != lanePercents ||
      oldDelegate.color != color ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.labelColor != labelColor;
}

// Full-pitch recovery diagram: a vertical average-regain band plus dots for
// verified outfield Recovery events.
class DefensiveActivityDiagram extends StatelessWidget {
  final List<Offset> events;
  final List<double> bands;
  final Color lineColor;
  final Color dotColor;
  const DefensiveActivityDiagram({
    super.key,
    required this.events,
    required this.bands,
    required this.lineColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: CustomPaint(
        painter: _DefensiveActivityPainter(
          events,
          bands,
          lineColor,
          dotColor,
        ),
      ),
    );
  }
}

class _DefensiveActivityPainter extends CustomPainter {
  final List<Offset> events;
  final List<double> bands;
  final Color lineColor;
  final Color dotColor;
  const _DefensiveActivityPainter(
    this.events,
    this.bands,
    this.lineColor,
    this.dotColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final bandPaint = Paint()
      ..color = const Color(0xFFB23A3A).withValues(alpha: 0.45);
    final bandWidth = size.width * 0.1;
    for (final bx in bands) {
      canvas.drawRect(
        Rect.fromLTWH(
            bx * size.width - bandWidth / 2, 0, bandWidth, size.height),
        bandPaint,
      );
    }

    final line = _pitchLinePaint(lineColor);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), line);
    canvas.drawLine(
        Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.height * 0.22, line);

    final goalW = size.width * 0.04;
    final goalH = size.height * 0.36;
    canvas.drawRect(
        Rect.fromLTWH(0, (size.height - goalH) / 2, goalW, goalH), line);
    canvas.drawRect(
        Rect.fromLTWH(
            size.width - goalW, (size.height - goalH) / 2, goalW, goalH),
        line);

    final dotPaint = Paint()..color = dotColor;
    for (final e in events) {
      canvas.drawCircle(
          Offset(e.dx * size.width, e.dy * size.height), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DefensiveActivityPainter oldDelegate) =>
      oldDelegate.events != events ||
      oldDelegate.bands != bands ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dotColor != dotColor;
}
