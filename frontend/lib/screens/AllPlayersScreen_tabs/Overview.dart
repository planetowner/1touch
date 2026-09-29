// ignore_for_file: file_names

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onetouch/core/season_label.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository_provider.dart';
import 'package:onetouch/features/player/player_indicator_value.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_indicators.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PlayerOverviewTab extends StatelessWidget {
  const PlayerOverviewTab(
      {super.key,
      this.player,
      this.playerId,
      this.onMatches,
      this.onTopBlockHeightChanged});
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  final VoidCallback? onMatches;
  final ValueChanged<double>? onTopBlockHeightChanged;

  String _clubHistoryKey(PlayerDetail detail, int index) {
    final teamId = detail.clubs[index].teamId;
    final repeatedTeam =
        detail.clubs.take(index).any((entry) => entry.teamId == teamId);
    return repeatedTeam ? '$teamId-$index' : '$teamId';
  }

  Widget _clubHistoryRow(
    BuildContext context,
    PlayerDetail detail,
    int index,
  ) {
    final club = detail.clubs[index];
    final historyKey = _clubHistoryKey(detail, index);
    final canOpenTeam = isTeamPageSupported(club.teamId);
    return GestureDetector(
      key: ValueKey('player-club-history-row-$historyKey'),
      behavior: HitTestBehavior.opaque,
      onTap: canOpenTeam ? () => openTeamPage(context, club.teamId) : null,
      child: Row(
        children: [
          PlayerRemoteImage(
            club.teamImage,
            key: ValueKey('player-club-history-logo-$historyKey'),
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teamNameLabel(
                context,
                club.teamId,
                club.teamName ?? '—',
              ),
              key: ValueKey('player-club-history-name-$historyKey'),
              style: Heading5.style,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${club.startDate?.year ?? '—'}–${club.endDate?.year ?? ''}',
            style: Body2.style,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: id,
      builder: (context, detail) {
        final foreground = Theme.of(context).colorScheme.onSurface;
        return SingleChildScrollView(
            key: const ValueKey('player-overview-scroll'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 144),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _PlayerOverviewProfileMeasure(
                onHeightChanged: onTopBlockHeightChanged,
                child: IntrinsicHeight(
                  child: Row(
                    key: const ValueKey('player-overview-top-block'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                          child: DefaultTextStyle(
                              style: Body1.style.copyWith(color: foreground),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${detail.profile.jerseyNumber ?? '—'}',
                                    key: const ValueKey(
                                        'player-overview-jersey-number'),
                                    style: Heading1.style.copyWith(
                                      color: foreground,
                                    ),
                                    textHeightBehavior:
                                        const TextHeightBehavior(
                                      applyHeightToFirstAscent: false,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    detail.currentPosition ?? '—',
                                    key: const ValueKey(
                                        'player-overview-position'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    teamNameLabel(
                                      context,
                                      detail.profile.teamId,
                                      detail.profile.teamName ?? '—',
                                    ),
                                    key: const ValueKey(
                                        'player-overview-team-name'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    detail.profile.nationality ?? '—',
                                    key: const ValueKey(
                                        'player-overview-country'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ))),
                      Align(
                        alignment: Alignment.topCenter,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ShaderMask(
                            key: const ValueKey(
                                'player-overview-image-bottom-fade'),
                            blendMode: BlendMode.dstIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white,
                                Colors.white,
                                Colors.transparent,
                              ],
                              stops: [0, 0.78, 1],
                            ).createShader(bounds),
                            child: PlayerRemoteImage(
                              detail.profile.image,
                              key: const ValueKey('player-overview-image'),
                              size: 160,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              PlayerBioStatsBlock(
                  player: player, playerId: id, profile: detail.profile),
              const SizedBox(height: 48),
              PlayerSection(
                  title: tr(context, 'COMPETITION STATS'),
                  titleAccessory: AppInfoButton(
                    key: const ValueKey('competition-stats-help-icon'),
                    message: tr(context,
                        'Competition statistics for the selected season.'),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerCompetitionTable(
                        key: const ValueKey('player-competition-stats-card'),
                        competitions: detail.competitions,
                      ),
                      const SizedBox(height: 12),
                      Opacity(
                        key:
                            const ValueKey('player-competition-collected-note'),
                        opacity: 0.5,
                        child: Text(
                          tr(context, 'Collected since 17/18 season'),
                          style: Body2.style.copyWith(
                            color: foreground,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  )),
              const SizedBox(height: 48),
              PlayerSection(
                  title: tr(context, 'MATCHES'),
                  trailing: SizedBox.square(
                    dimension: 24,
                    child: IconButton(
                        key: const ValueKey('player-matches-arrow'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 24,
                          height: 24,
                        ),
                        iconSize: 24,
                        icon: const Icon(Icons.chevron_right),
                        tooltip: tr(context, 'All matches'),
                        onPressed: onMatches),
                  ),
                  child: Column(children: [
                    if (detail.matches.isEmpty)
                      Text(tr(context, 'No appearances this season')),
                    for (final match in detail.matches.take(3))
                      PlayerDetailMatchCard(match: match),
                  ])),
              const SizedBox(height: 48),
              PlayerSection(
                  title: tr(context, 'CLUB HISTORY'),
                  child: PlayerSurface(
                      key: const ValueKey('player-club-history-card'),
                      child: Column(children: [
                        if (detail.clubs.isEmpty)
                          Text(tr(context, 'Club history unavailable')),
                        for (var index = 0;
                            index < detail.clubs.length;
                            index++) ...[
                          _clubHistoryRow(context, detail, index),
                          if (index != detail.clubs.length - 1)
                            const SizedBox(height: 16),
                        ],
                      ]))),
            ]));
      });
}

class _PlayerOverviewProfileMeasure extends StatefulWidget {
  const _PlayerOverviewProfileMeasure({
    required this.child,
    this.onHeightChanged,
  });

  final Widget child;
  final ValueChanged<double>? onHeightChanged;

  @override
  State<_PlayerOverviewProfileMeasure> createState() =>
      _PlayerOverviewProfileMeasureState();
}

class _PlayerOverviewProfileMeasureState
    extends State<_PlayerOverviewProfileMeasure> {
  final _measureKey = GlobalKey();
  double? _lastHeight;
  bool _reportScheduled = false;

  void _scheduleReport() {
    if (_reportScheduled || widget.onHeightChanged == null) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      final height = _measureKey.currentContext?.size?.height;
      if (height == null || height == _lastHeight) return;
      _lastHeight = height;
      widget.onHeightChanged!(height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleReport();
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _scheduleReport();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: SizedBox(key: _measureKey, child: widget.child),
      ),
    );
  }
}

class PlayerBioStatsBlock extends StatefulWidget {
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  final PlayerIndicatorsRepository? repository;
  final PlayerDetailProfile? profile;

  const PlayerBioStatsBlock({
    super.key,
    this.player,
    this.playerId,
    this.repository,
    this.profile,
  });

  @override
  State<PlayerBioStatsBlock> createState() => _PlayerBioStatsBlockState();
}

class _PlayerBioStatsBlockState extends State<PlayerBioStatsBlock> {
  PlayerIndicators? _indicators;
  bool _loading = false;
  bool _failed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlayerBioStatsBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    final requestId = ++_requestId;
    final playerId = widget.id;
    _indicators = null;
    _failed = false;
    _loading = playerId != null;
    if (playerId != null) unawaited(_fetch(playerId, requestId));
  }

  Future<void> _fetch(int playerId, int requestId) async {
    try {
      final result = await (widget.repository ?? playerIndicatorsRepository)
          .loadCurrent(playerId);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _indicators = result;
        _loading = false;
      });
    } on Object {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  String _explanation({required bool cost}) {
    final score = cost ? _indicators?.costEffectiveness : _indicators?.form;
    final definition = cost
        ? tr(
            context,
            'Compares season rating and share of playing time with expectations '
            "for the player's estimated gross wage, club wage level, league "
            'and position. The two differences carry equal weight. '
            'Fair means within the usual prediction error; higher grades mean '
            'more return for the wage. Transfer fees are not included.')
        : tr(
            context,
            'Recent performance over the latest 5 league appearances this season, '
            'weighted by playing time and calibrated recency. '
            'Compared with all positions across the five leagues.');
    final season = _indicators?.seasonName;
    final scope = season == null
        ? tr(context, 'Current season only.')
        : tr(context, 'Current season: {season}.',
            {'season': compactSeasonLabel(season)});
    final evidence = score?.grade == null
        ? switch (score?.unavailableReason) {
            'wage_unavailable' => tr(context, 'Wage data is unavailable.'),
            'no_rated_matches' =>
              tr(context, 'No rated appearances are available.'),
            _ => _failed
                ? tr(context,
                    'Could not load the indicators. Tap retry to try again.')
                : tr(context,
                    'An indicator is shown when enough data is available.'),
          }
        : '${tr(context, '{matches} rated appearances. {players} players across the five leagues.', {
                'matches': score!.ratedMatches,
                'players': score.referenceCount
              })} '
            '${cost ? tr(context, 'Grades are based on prediction error, not equal-sized groups.') : ''}';
    return '$definition\n\n$scope $evidence';
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final appColors = AppColors.of(context);
    final birthDate = widget.profile == null
        ? DateTime.tryParse(player?.dateOfBirth ?? '')
        : widget.profile!.birthDate;
    final now = DateTime.now();
    final age = birthDate == null
        ? null
        : now.year -
            birthDate.year -
            ((now.month < birthDate.month ||
                    (now.month == birthDate.month && now.day < birthDate.day))
                ? 1
                : 0);
    final columns = <List<({String label, Widget value, String? explanation})>>[
      [
        (
          label: tr(context, 'Height'),
          value: Text(
              widget.profile == null
                  ? (player == null ? '—' : '${player.heightCm}cm')
                  : widget.profile!.heightCm == null
                      ? '—'
                      : '${widget.profile!.heightCm}cm',
              style: Heading5.style),
          explanation: null
        ),
        (
          label: tr(context, 'Age'),
          value: Text(
              age == null ? '—' : tr(context, '{age} yrs', {'age': age}),
              style: Heading5.style),
          explanation: null
        ),
        (
          label: tr(context, 'Form'),
          value: PlayerIndicatorValue(
            key: const ValueKey('player-form'),
            score: _indicators?.form,
            loading: _loading,
            failed: _failed,
            explanation: _explanation(cost: false),
            onRetry: () => setState(_load),
          ),
          explanation: null,
        ),
      ],
      [
        (
          label: tr(context, 'Weight'),
          value: Text(
              widget.profile == null
                  ? (player == null ? '—' : '${player.weightKg}kg')
                  : widget.profile!.weightKg == null
                      ? '—'
                      : '${widget.profile!.weightKg}kg',
              style: Heading5.style),
          explanation: null
        ),
        (
          label: tr(context, 'Squad Role'),
          value: PlayerIndicatorValue(
            key: const ValueKey('player-squad-role'),
            label: _indicators?.squadRole,
            loading: _loading,
            failed: _failed,
            explanation:
                'Based on league playing time while available at this club, '
                'excluding recorded injuries and suspensions. '
                'Prospect means low usage and age 21 or younger on the date the '
                'role is calculated. A role is shown after it has been calculated '
                'from verified data.',
            onRetry: () => setState(_load),
          ),
          explanation: null
        ),
        (
          label: tr(context, 'Cost-Effectiveness'),
          value: PlayerIndicatorValue(
            key: const ValueKey('player-cost-effectiveness'),
            score: _indicators?.costEffectiveness,
            loading: _loading,
            failed: _failed,
            explanation: _explanation(cost: true),
            onRetry: () => setState(_load),
          ),
          explanation: _explanation(cost: true),
        ),
      ],
    ];
    return Container(
      key: const ValueKey('player-bio-stats-card'),
      decoration: BoxDecoration(
        color: appColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: appCardShadows(context),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var columnIndex = 0;
              columnIndex < columns.length;
              columnIndex++) ...[
            if (columnIndex > 0) const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  for (var itemIndex = 0;
                      itemIndex < columns[columnIndex].length;
                      itemIndex++) ...[
                    if (itemIndex > 0)
                      Divider(
                        color: appColors.divider,
                        height: 34,
                        thickness: 2,
                      ),
                    _PlayerBioCell(
                      label: columns[columnIndex][itemIndex].label,
                      value: columns[columnIndex][itemIndex].value,
                      explanation: columns[columnIndex][itemIndex].explanation,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayerBioCell extends StatelessWidget {
  const _PlayerBioCell(
      {required this.label, required this.value, this.explanation});

  final String label;
  final Widget value;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
            width: double.infinity,
            height: 18,
            child: Row(
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(tr(context, label), style: Body1.style),
                  ),
                ),
                if (explanation != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: AppInfoButton(
                      key: const ValueKey('player-cost-effectiveness-info'),
                      message:
                          'Measured by comparing actual salary against 1Touch’s predicted market value based on performance and playtime.',
                      layoutSize: 16,
                    ),
                  ),
              ],
            )),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 22, child: value),
      ],
    );
  }
}
