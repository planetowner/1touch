import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository.dart';
import 'package:onetouch/data/best_eleven/best_eleven_repository_provider.dart';
import 'package:onetouch/data/current_form/current_form_repository.dart';
import 'package:onetouch/data/current_form/current_form_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/teams/mock/team_analysis_catalog.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/TeamScreenFeatures.dart';
import 'package:onetouch/models/current_form.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/models/team_attribute_scores.dart';
import 'package:onetouch/models/team_best_eleven.dart';

class AnalysisTab extends StatelessWidget {
  final Map<String, dynamic>? team;

  const AnalysisTab({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AttributesSection(team: team),
          ProbabilitySection(),
          BestElevenSection(team: team),
          CurrentFormSection(team: team),
        ],
      ),
    );
  }
}

class _AnalysisSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _AnalysisSectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final control = trailing;
    if (control == null) return Text(title, style: Body2_b.style);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Body2_b.style),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                  child: control,
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(title, style: Body2_b.style), control],
        );
      },
    );
  }
}

//
// ATTRIBUTES — radar chart comparing the current team to a chosen reference
// (same team, different season).
//

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
    final currentSeasonIds = seasonRepository.allSeasons
        .where((season) => season.isCurrent)
        .map((season) => season.seasonId)
        .toSet();
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
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: Text('No attribute data available',
            style: TextStyle(color: AppColors.of(context).mutedForeground)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //   Header: title + comparison picker
          _AnalysisSectionHeader(
            title: 'ATTRIBUTES',
            trailing:
                _comparisonOptions.isNotEmpty ? _buildComparisonPill() : null,
          ),
          const SizedBox(height: 16),

          //   Radar chart container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            decoration: BoxDecoration(
              color: AppColors.of(context).subtleBackground,
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildRadarChart(),
          ),

          //   Legend
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 20,
            runSpacing: 8,
            children: [
              _legendDot(const Color(0xFFE8434A), 'MY TEAM'),
              if (_comparisonScores != null)
                _legendDot(
                  Theme.of(context).colorScheme.onSurface,
                  '${_comparisonScores!.seasonLabel} '
                  '${teamRepository.findByIdOrUnknown(_comparisonScores!.teamId).name.toUpperCase()}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  //   Comparison picker pill (season-only for now)

  Widget _buildComparisonPill() {
    final team = teamRepository.findByIdOrUnknown(_teamId);
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          key: const ValueKey('analysis-attributes-filter'),
          value: _comparisonScores?.seasonId,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: AppColors.of(context).cardBackground,
          style: Body2_b.style.copyWith(color: colors.onSurface),
          onChanged: (seasonId) {
            if (seasonId == null) return;
            setState(() {
              _comparisonScores =
                  _comparisonOptions.firstWhere((s) => s.seasonId == seasonId);
            });
          },
          selectedItemBuilder: (_) => _comparisonOptions
              .map((s) => _pillContent(s.seasonLabel, team))
              .toList(),
          items: _comparisonOptions
              .map(
                (s) => DropdownMenuItem(
                  value: s.seasonId,
                  child: Text(
                    '${s.seasonLabel.toUpperCase()}  ${team.shortCode ?? team.name}',
                    style: Body2_b.style.copyWith(color: colors.onSurface),
                  ),
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
        Text(
          seasonLabel.toUpperCase(),
          style: Body2_b.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 14, color: AppColors.of(context).divider),
        const SizedBox(width: 8),
        Image.network(
          team.imagePath ?? '',
          width: 16,
          height: 16,
          errorBuilder: (_, __, ___) => Icon(
            Icons.shield,
            size: 16,
            color: AppColors.of(context).mutedForeground,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          team.shortCode ?? team.name,
          style: Body2_b.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  //   Radar chart

  // Fixed frame for the radar's scale. fl_chart derives the chart's center and
  // radius from the min/max value across ALL datasets, so without a pinned
  // range MY TEAM's polygon would rescale (and visibly change shape) every time
  // a different comparison season is picked. Anchoring the floor/ceiling keeps
  // MY TEAM identical no matter what it's compared to. Attribute values are
  // clamped to 5-95, so 0..100 gives clean headroom and aligns with tickCount.
  static const double _radarFloor = 0;
  static const double _radarCeil = 100;

  Widget _buildRadarChart() {
    final appColors = AppColors.of(context);
    final comparisonColor = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: 260,
      child: RadarChart(
        RadarChartData(
          radarShape: RadarShape.polygon,
          tickCount: 4,
          gridBorderData: BorderSide(color: appColors.divider, width: 1),
          radarBorderData: BorderSide(color: appColors.divider, width: 1),
          tickBorderData: BorderSide(color: appColors.divider, width: 1),
          ticksTextStyle:
              const TextStyle(color: Colors.transparent, fontSize: 0),
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
                fillColor: comparisonColor.withValues(alpha: 0.1),
                borderColor: comparisonColor.withValues(alpha: 0.85),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Body2_b.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class BestElevenSection extends StatefulWidget {
  final Map<String, dynamic>? team;
  final BestElevenRepository? repository;

  const BestElevenSection({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  State<BestElevenSection> createState() => _BestElevenSectionState();
}

class _BestElevenSectionState extends State<BestElevenSection> {
  TeamBestEleven? _lineup;
  List<BestElevenFormationOption> _formations = const [];
  String? _selectedFormation;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  BestElevenRepository get _repository =>
      widget.repository ?? bestElevenRepository;

  int? get _teamId => widget.team?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(BestElevenSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_teamId != oldWidget.team?['id'] ||
        widget.repository != oldWidget.repository) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cached = teamId == null ? null : _repository.cachedForTeam(teamId);

    _lineup = cached;
    _formations = cached?.formations ?? const [];
    _selectedFormation = cached?.formation;
    _isLoading = teamId != null && cached == null;
    _loadFailed = false;

    if (_isLoading) {
      unawaited(_loadLineup(teamId!, requestId));
    }
  }

  Future<void> _loadLineup(
    int teamId,
    int requestId, {
    String? formation,
  }) async {
    try {
      final lineup = await _repository.loadForTeam(
        teamId,
        formation: formation,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _lineup = lineup;
        if (lineup != null) {
          _formations = lineup.formations;
          _selectedFormation = lineup.formation;
        }
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  void _changeFormation(String formation) {
    final teamId = _teamId;
    if (teamId == null || formation == _selectedFormation) return;

    final requestId = ++_loadRequestId;
    final cached = _repository.cachedForTeam(teamId, formation: formation);
    setState(() {
      _selectedFormation = formation;
      _lineup = cached;
      if (cached != null) _formations = cached.formations;
      _isLoading = cached == null;
      _loadFailed = false;
    });

    if (cached == null) {
      unawaited(_loadLineup(teamId, requestId, formation: formation));
    }
  }

  void _retryLoad() {
    final teamId = _teamId;
    if (teamId == null) return;

    final requestId = ++_loadRequestId;
    final formation = _selectedFormation;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    unawaited(_loadLineup(teamId, requestId, formation: formation));
  }

  String _formationLabel(BestElevenFormationOption option) {
    final percentage = option.usagePercentage;
    if (percentage == null) return option.formation;
    final formatted = percentage == percentage.roundToDouble()
        ? percentage.toInt().toString()
        : percentage.toStringAsFixed(1);
    return '${option.formation} ($formatted%)';
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Dropdown
          _AnalysisSectionHeader(
            title: 'BEST ELEVEN',
            trailing: _formations.isEmpty
                ? null
                : Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                    decoration: BoxDecoration(
                      color: appColors.subtleBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const ValueKey('analysis-formation-filter'),
                        value: _selectedFormation,
                        icon: Icon(
                          Icons.keyboard_arrow_down,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        dropdownColor: appColors.cardBackground,
                        style: Body2_b.style.copyWith(color: colors.onSurface),
                        onChanged: _isLoading
                            ? null
                            : (formation) {
                                if (formation != null) {
                                  _changeFormation(formation);
                                }
                              },
                        items: _formations.map((option) {
                          final label = _formationLabel(option).toUpperCase();
                          return DropdownMenuItem(
                            value: option.formation,
                            child: Text(
                              label,
                              style: Body2_b.style
                                  .copyWith(color: colors.onSurface),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  key: ValueKey('analysis-best-eleven-loading'),
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_loadFailed)
            Row(
              key: const ValueKey('analysis-best-eleven-error'),
              children: [
                Expanded(
                  child: Text(
                    'Unable to load best eleven',
                    style: Body2.style,
                  ),
                ),
                TextButton(onPressed: _retryLoad, child: const Text('RETRY')),
              ],
            )
          else if (_lineup == null || _lineup!.players.isEmpty)
            Padding(
              key: const ValueKey('analysis-best-eleven-empty'),
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No best eleven available',
                style: Body2.style,
              ),
            )
          else
            BestElevenPitch(players: _lineup!.players),
        ],
      ),
    );
  }
}

class CurrentFormSection extends StatefulWidget {
  final Map<String, dynamic>? team;
  final CurrentFormRepository? repository;

  const CurrentFormSection({
    super.key,
    required this.team,
    this.repository,
  });

  @override
  State<CurrentFormSection> createState() => _CurrentFormSectionState();
}

class _CurrentFormSectionState extends State<CurrentFormSection> {
  List<CurrentFormOption> _options = const [];
  CurrentFormOption? _selectedOption;
  CurrentFormComparison? _comparison;
  bool _isLoading = false;
  bool _loadFailed = false;
  int _loadRequestId = 0;

  CurrentFormRepository get _repository =>
      widget.repository ?? currentFormRepository;

  int? get _teamId => widget.team?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _startDefaultLoad();
  }

  @override
  void didUpdateWidget(CurrentFormSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_teamId != oldWidget.team?['id'] ||
        widget.repository != oldWidget.repository) {
      _startDefaultLoad();
    }
  }

  void _startDefaultLoad() {
    final teamId = _teamId;
    final requestId = ++_loadRequestId;
    final cachedOptions =
        teamId == null ? null : _repository.cachedOptionsFor(teamId);
    final selectedOption = teamId == null || cachedOptions == null
        ? null
        : _defaultOption(cachedOptions, teamId);
    final cachedComparison = selectedOption == null
        ? null
        : _repository.cachedComparisonFor(
            teamId!,
            compareTeamId: selectedOption.teamId,
            compareSeasonId: selectedOption.seasonId,
          );

    _options = cachedOptions ?? const [];
    _selectedOption = selectedOption;
    _comparison = cachedComparison;
    _loadFailed = false;
    _isLoading = teamId != null &&
        (cachedOptions == null ||
            (selectedOption != null && cachedComparison == null));

    if (teamId == null) return;
    if (cachedOptions == null) {
      unawaited(_loadOptions(teamId, requestId));
    } else if (selectedOption != null && cachedComparison == null) {
      unawaited(_loadComparison(teamId, selectedOption, requestId));
    }
  }

  Future<void> _loadOptions(int teamId, int requestId) async {
    try {
      final options = await _repository.loadOptions(teamId);
      if (!mounted || requestId != _loadRequestId) return;

      final selectedOption = _defaultOption(options, teamId);
      final cachedComparison = selectedOption == null
          ? null
          : _repository.cachedComparisonFor(
              teamId,
              compareTeamId: selectedOption.teamId,
              compareSeasonId: selectedOption.seasonId,
            );
      setState(() {
        _options = options;
        _selectedOption = selectedOption;
        _comparison = cachedComparison;
        _isLoading = selectedOption != null && cachedComparison == null;
      });

      if (selectedOption != null && cachedComparison == null) {
        unawaited(_loadComparison(teamId, selectedOption, requestId));
      }
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _loadComparison(
    int teamId,
    CurrentFormOption option,
    int requestId,
  ) async {
    try {
      final comparison = await _repository.loadComparison(
        teamId,
        compareTeamId: option.teamId,
        compareSeasonId: option.seasonId,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _comparison = comparison;
        _isLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  CurrentFormOption? _defaultOption(
    List<CurrentFormOption> options,
    int teamId,
  ) {
    if (options.isEmpty) return null;

    final sameTeam =
        options.where((option) => option.teamId == teamId).toList();
    // Backend options are newest-first, so the second same-team row is the
    // previous season while the full list remains available for comparison.
    if (sameTeam.length > 1) return sameTeam[1];
    if (sameTeam.isNotEmpty) return sameTeam.first;
    return options.first;
  }

  void _changeComparison(CurrentFormOption option) {
    final teamId = _teamId;
    if (teamId == null || identical(option, _selectedOption)) return;

    final requestId = ++_loadRequestId;
    final cached = _repository.cachedComparisonFor(
      teamId,
      compareTeamId: option.teamId,
      compareSeasonId: option.seasonId,
    );
    setState(() {
      _selectedOption = option;
      _comparison = cached;
      _isLoading = cached == null;
      _loadFailed = false;
    });

    if (cached == null) {
      unawaited(_loadComparison(teamId, option, requestId));
    }
  }

  void _retryLoad() {
    final teamId = _teamId;
    if (teamId == null) return;

    final option = _selectedOption;
    if (option == null) {
      setState(_startDefaultLoad);
      return;
    }

    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    unawaited(_loadComparison(teamId, option, requestId));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnalysisSectionHeader(
            title: 'CURRENT FORM',
            trailing: _options.isNotEmpty ? _buildComparisonPicker() : null,
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: SizedBox.square(
                  key: ValueKey('analysis-current-form-loading'),
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_loadFailed)
            Row(
              key: const ValueKey('analysis-current-form-error'),
              children: [
                Expanded(
                  child: Text(
                    'Unable to load current form',
                    style: Body2.style,
                  ),
                ),
                TextButton(onPressed: _retryLoad, child: const Text('RETRY')),
              ],
            )
          else if (_comparison == null || _comparison!.current.points.isEmpty)
            _buildEmptyState()
          else
            _buildChart(),
          if (!_isLoading &&
              !_loadFailed &&
              _comparison != null &&
              _comparison!.current.points.isNotEmpty)
            _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildComparisonPicker() {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CurrentFormOption>(
          key: const ValueKey('analysis-form-filter'),
          value: _selectedOption,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          dropdownColor: AppColors.of(context).cardBackground,
          style: Body2_b.style.copyWith(color: colors.onSurface),
          onChanged: _isLoading
              ? null
              : (option) {
                  if (option != null) _changeComparison(option);
                },
          selectedItemBuilder: (_) => _options.map((option) {
            return _comparisonLabel(option);
          }).toList(),
          items: _options
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: _comparisonLabel(option),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _comparisonLabel(CurrentFormOption option) {
    final teamCode =
        (option.teamShortCode ?? option.teamName ?? '').toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          option.seasonName.toUpperCase(),
          style: Body2_b.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 1, height: 16, color: AppColors.of(context).divider),
        const SizedBox(width: 8),
        _teamLogo(option.teamLogo),
        const SizedBox(width: 6),
        Text(
          teamCode,
          style: Body2_b.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _teamLogo(String? logo) {
    if (logo == null || logo.isEmpty) {
      return Icon(
        Icons.shield,
        size: 18,
        color: AppColors.of(context).mutedForeground,
      );
    }

    return Image.network(
      logo,
      width: 18,
      height: 18,
      errorBuilder: (_, __, ___) => Icon(
        Icons.shield,
        size: 18,
        color: AppColors.of(context).mutedForeground,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      key: const ValueKey('analysis-current-form-empty'),
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: Text(
        'Current form data is not available yet',
        style: Body2.style.copyWith(
          color: AppColors.of(context).mutedForeground,
        ),
      ),
    );
  }

  Widget _buildChart() {
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final data = _comparison!;
    final current = data.current;
    final comparison = data.comparison;
    final maxRound = math.max(2, data.maxRound);
    final maxPoints = math.max(5, ((data.maxPoints + 4) ~/ 5) * 5).toDouble();

    return Container(
      height: 346,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: appColors.subtleBackground,
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
                      minX: 0,
                      maxX: maxRound.toDouble(),
                      minY: 0,
                      maxY: maxPoints,
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxPoints / 8,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: appColors.divider,
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
                          getTooltipColor: (_) => colorScheme.onSurface,
                          getTooltipItems: (spots) => spots
                              .map(
                                (spot) => LineTooltipItem(
                                  'Round ${spot.x.toInt()}  ${spot.y.toInt()} Pts',
                                  Body2_b.style.copyWith(
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        getTouchedSpotIndicator: (bar, indexes) => indexes
                            .map(
                              (_) => TouchedSpotIndicatorData(
                                FlLine(
                                  color: appColors.mutedForeground,
                                  strokeWidth: 1,
                                  dashArray: [6, 6],
                                ),
                                FlDotData(
                                  getDotPainter: (_, __, ___, ____) =>
                                      FlDotCirclePainter(
                                    radius: 4,
                                    color: bar.color ?? colorScheme.onSurface,
                                    strokeWidth: 0,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      lineBarsData: [
                        _formLine(current, const Color(0xFFFF525D)),
                        _formLine(comparison, colorScheme.onSurface),
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

  LineChartBarData _formLine(CurrentFormSeries series, Color color) {
    return LineChartBarData(
      spots: series.points
          .map(
            (point) => FlSpot(
              point.roundNo.toDouble(),
              point.cumulativePoints.toDouble(),
            ),
          )
          .toList(),
      color: color,
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
    );
  }

  Widget _buildLegend() {
    final comparison = _comparison!.comparison;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 20,
        runSpacing: 8,
        children: [
          _legendItem(const Color(0xFFFF525D), 'CURRENT'),
          _legendItem(
            Theme.of(context).colorScheme.onSurface,
            '${comparison.seasonName} '
            '${(comparison.teamShortCode ?? comparison.teamName ?? '').toUpperCase()}',
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Body2_b.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
                  context,
                  title: "Chances to win\nUCL Trophy",
                  value: 16,
                  delta: 3,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _probabilityBox(
                  context,
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

  Widget _probabilityBox(
    BuildContext context, {
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
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Body1.style),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$value', style: Heading1.style),
                      Text('%', style: Heading4.style),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    children: [
                      Icon(arrow, color: arrowColor, size: 24),
                      Text('$delta', style: Heading5.style),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
