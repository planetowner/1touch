import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_comparison_colors.dart';
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
    final keyPasses = _pairedStatistic('key-passes');
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
            if (tacticalAvailable || shotMapAvailable || keyPasses != null) ...[
              const SizedBox(height: 48),
              _buildAttackBlock(keyPasses),
            ],
            if (_possessionRows().isNotEmpty) ...[
              const SizedBox(height: 48),
              _buildPossessionBlock(),
            ],
            if (tacticalAvailable) ...[
              const SizedBox(height: 48),
              _buildProgressionBlock(),
            ],
            if (!tacticalAvailable && !shotMapAvailable) ...[
              const SizedBox(height: 48),
              _buildUnavailableNotice(),
            ],
          ],
          if (tacticalAvailable || _defenseRows().isNotEmpty) ...[
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
          boxShadow: appCardShadows(context),
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
      homeTeamName: home.displayName,
      awayTeamName: away.displayName,
      homeScore: widget.fixture.homeScore?.toString() ?? '#',
      awayScore: widget.fixture.awayScore?.toString() ?? '#',
      statusLabel: isLive ? '42:02' : 'Final',
      roundLabel: widget.fixture.displayRoundLabel,
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

  Widget _buildAttackBlock(({double home, double away})? keyPasses) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final cardBackground = isDark ? AppPalette.darkGrey : AppPalette.white;
    final comparisonColors = _comparisonColors(cardBackground);
    final selectedTeamColor =
        showHome ? comparisonColors.anchor : comparisonColors.opponent;
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
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appCardShadows(context),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTeamToggle(),
                const SizedBox(height: 24),
                if (_shotMap?.available == true) ...[
                  ShotMapDiagram(
                    shots: _selectedShotPlots,
                    color: selectedTeamColor,
                    lineColor: foreground.withValues(alpha: 0.30),
                  ),
                  const SizedBox(height: 24),
                  _buildStatRow('Goals', homeGoals, awayGoals),
                  _buildStatRow('Shots on Target', homeShots, awayShots),
                ],
                // 키패스는 Opta 전술 분석과 별개인 Sportmonks 팀 통계를 사용해요.
                if (keyPasses != null)
                  _buildStatRow(
                    'Key Passes',
                    keyPasses.home,
                    keyPasses.away,
                  ),
                if (_analysis?.available == true) ...[
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
              boxShadow: appCardShadows(context),
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
    final comparisonColors = _comparisonColors(
      isDark ? AppPalette.darkGrey : AppPalette.white,
    );
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
                    color: comparisonColors.opponent,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      key: const ValueKey('match-possession-home-fill'),
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: ColoredBox(color: comparisonColors.anchor),
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
                            color: _readableTextColor(comparisonColors.anchor),
                          ),
                        ),
                        Text(
                          _formatNumber(away, suffix: '%'),
                          style: Heading4.style.copyWith(
                            color: _readableTextColor(
                              comparisonColors.opponent,
                            ),
                          ),
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

  Color _readableTextColor(Color background) {
    final blackContrast =
        ColorUtils.getContrastRatio(background, AppPalette.black);
    final whiteContrast =
        ColorUtils.getContrastRatio(background, AppPalette.white);
    return blackContrast >= whiteContrast ? AppPalette.black : AppPalette.white;
  }

  Widget _buildProgressionBlock() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBackground = isDark ? AppPalette.darkGrey : AppPalette.white;
    final comparisonColors = _comparisonColors(cardBackground);
    final selectedTeamColor =
        showHome ? comparisonColors.anchor : comparisonColors.opponent;
    final selected = _selectedAnalysis?.progression;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("PROGRESSION", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: [
              _buildTeamToggle(),
              const SizedBox(height: 24),
              ProgressionDiagram(
                lanePercents: _channelPercentages(selected),
                rightToLeft: !showHome,
                color: selectedTeamColor,
                labelColor: _readableTextColor(selectedTeamColor),
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

  TeamComparisonColors _comparisonColors(Color background) {
    final homeTeam = fixtureHomeTeam(widget.fixture, teamRepository);
    final awayTeam = fixtureAwayTeam(widget.fixture, teamRepository);
    return TeamComparisonColorResolver.resolve(
      anchorTeamName: homeTeam.name,
      anchorPrimaryFallback: Color(homeTeam.primaryColor),
      opponentTeamName: awayTeam.name,
      opponentPrimaryFallback: Color(awayTeam.primaryColor),
      background: background,
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
    final cardBackground = isDark ? AppPalette.darkGrey : AppPalette.white;
    final comparisonColors = _comparisonColors(cardBackground);
    final selectedTeamColor =
        showHome ? comparisonColors.anchor : comparisonColors.opponent;
    final rows = _defenseRows();
    final zoneDeltas = _defenseZoneDeltas();
    final missingPositionCount = [
      _homeAnalysis?.defensiveActivity,
      _awayAnalysis?.defensiveActivity,
    ].fold<int>(
      0,
      (total, activity) =>
          total +
          (activity?.complete == false
              ? activity?.missingPositionCount ?? 0
              : 0),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('DEFENSE', style: Body2_b.style),
              SizedBox(width: 4),
              Tooltip(
                message:
                    'Pitch values compare each team’s share of recoveries by third.',
                child: Icon(Icons.help_outline, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('match-analysis-defense-card'),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: appCardShadows(context),
            ),
            child: Column(
              children: [
                _buildTeamToggle(),
                if (zoneDeltas != null) ...[
                  const SizedBox(height: 24),
                  DefenseTerritoryDiagram(
                    zoneDeltas: zoneDeltas,
                    selectedTeamColor: selectedTeamColor,
                    lineColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ],
                if (zoneDeltas == null && missingPositionCount > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Recovery comparison incomplete '
                    '($missingPositionCount missing)',
                    style: Body2.style.copyWith(
                      color: AppColors.of(context).mutedForeground,
                    ),
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

  List<double>? _defenseZoneDeltas() {
    final home = _defenseZonePercentages(_homeAnalysis?.defensiveActivity);
    final away = _defenseZonePercentages(_awayAnalysis?.defensiveActivity);
    if (home == null || away == null) return null;
    final selected = showHome ? home : away;
    final opponent = showHome ? away : home;
    return List.generate(
      3,
      (index) => selected[index] - opponent[index],
      growable: false,
    );
  }

  List<double>? _defenseZonePercentages(MatchDefensiveActivity? activity) {
    if (activity == null || !activity.complete || activity.actions.isEmpty) {
      return null;
    }
    final counts = [0, 0, 0];
    for (final action in activity.actions) {
      final zone = (action.x.clamp(0, 99.999) / (100 / 3)).floor();
      counts[zone] += 1;
    }
    final total = activity.actions.length;
    return List.generate(
      3,
      (index) => counts[index] * 100 / total,
      growable: false,
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
    final goalPaint = Paint()..color = color;

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

// Team-relative recovery distribution across the defensive, middle, and
// attacking thirds. Each value is the selected team's share minus its
// opponent's share, so the three displayed differences sum to roughly zero.
class DefenseTerritoryDiagram extends StatelessWidget {
  final List<double> zoneDeltas;
  final Color selectedTeamColor;
  final Color lineColor;
  const DefenseTerritoryDiagram({
    super.key,
    required this.zoneDeltas,
    required this.selectedTeamColor,
    required this.lineColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: AspectRatio(
        key: const ValueKey('match-defense-territory'),
        aspectRatio: 1.6,
        child: CustomPaint(
          painter: _DefenseTerritoryPainter(
            zoneDeltas,
            selectedTeamColor,
            lineColor,
          ),
        ),
      ),
    );
  }
}

class _DefenseTerritoryPainter extends CustomPainter {
  final List<double> zoneDeltas;
  final Color selectedTeamColor;
  final Color lineColor;
  const _DefenseTerritoryPainter(
    this.zoneDeltas,
    this.selectedTeamColor,
    this.lineColor,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final zoneWidth = size.width / 3;
    for (var index = 0; index < 3; index += 1) {
      final delta = zoneDeltas[index];
      canvas.drawRect(
        Rect.fromLTWH(index * zoneWidth, 0, zoneWidth, size.height),
        Paint()
          ..color = selectedTeamColor.withValues(
            alpha: defenseTerritoryOpacity(delta),
          ),
      );
    }

    final line = _pitchLinePaint(lineColor);
    final pitch = (Offset.zero & size).deflate(line.strokeWidth / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitch, const Radius.circular(5)),
      line,
    );
    for (final fraction in const [1 / 3, 1 / 2, 2 / 3]) {
      canvas.drawLine(
        Offset(size.width * fraction, 0),
        Offset(size.width * fraction, size.height),
        line,
      );
    }
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.height * 0.17,
      line,
    );

    final boxWidth = size.width * 0.13;
    final boxTop = size.height * 0.20;
    final boxHeight = size.height * 0.60;
    canvas.drawRect(Rect.fromLTWH(0, boxTop, boxWidth, boxHeight), line);
    canvas.drawRect(
      Rect.fromLTWH(size.width - boxWidth, boxTop, boxWidth, boxHeight),
      line,
    );

    final arrowColor = AppPalette.white.withValues(alpha: 0.48);
    final arrowShaft = defenseTerritoryArrowShaftRect(size);
    final arrowY = arrowShaft.center.dy;
    final arrowShoulder = arrowShaft.right;
    final arrowTip = math.min(
      size.width - defenseTerritoryArrowHorizontalInset,
      arrowShoulder + defenseTerritoryArrowHeadWidth,
    );
    final arrowHeadTop = arrowY - size.height * 0.18;
    canvas.drawRect(arrowShaft, Paint()..color = arrowColor);
    canvas.drawPath(
      Path()
        ..moveTo(arrowShoulder, arrowHeadTop)
        ..lineTo(arrowTip, arrowY)
        ..lineTo(arrowShoulder, arrowY + size.height * 0.18)
        ..close(),
      Paint()..color = arrowColor,
    );

    for (var index = 0; index < 3; index += 1) {
      final value = zoneDeltas[index];
      final label = value >= 0
          ? '+${value.toStringAsFixed(1)}%'
          : '${value.toStringAsFixed(1)}%';
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: Heading4.style.copyWith(color: AppPalette.white),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: zoneWidth);
      text.paint(
        canvas,
        Offset(
          zoneWidth * (index + 0.5) - text.width / 2,
          defenseTerritoryLabelTop(
            labelHeight: text.height,
            arrowHeadTop: arrowHeadTop,
          ),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DefenseTerritoryPainter oldDelegate) =>
      oldDelegate.zoneDeltas != zoneDeltas ||
      oldDelegate.selectedTeamColor != selectedTeamColor ||
      oldDelegate.lineColor != lineColor;
}

double defenseTerritoryOpacity(double zoneDelta) =>
    (0.5 + zoneDelta / 100).clamp(0.0, 1.0).toDouble();

const double defenseTerritoryArrowShaftWidth = 233;
const double defenseTerritoryArrowShaftHeight = 28;
const double defenseTerritoryArrowHeadWidth = 36;
const double defenseTerritoryArrowHorizontalInset = 8;
const double defenseTerritoryLabelGap = 8;

Rect defenseTerritoryArrowShaftRect(Size size) {
  final availableWidth = math.max(
    0.0,
    size.width -
        defenseTerritoryArrowHeadWidth -
        defenseTerritoryArrowHorizontalInset * 2,
  );
  final width = math.min(defenseTerritoryArrowShaftWidth, availableWidth);
  final totalArrowWidth = width + defenseTerritoryArrowHeadWidth;
  return Rect.fromLTWH(
    (size.width - totalArrowWidth) / 2,
    size.height / 2,
    width,
    defenseTerritoryArrowShaftHeight,
  );
}

double defenseTerritoryLabelTop({
  required double labelHeight,
  required double arrowHeadTop,
}) =>
    math.max(
      defenseTerritoryArrowHorizontalInset,
      arrowHeadTop - defenseTerritoryLabelGap - labelHeight,
    );
