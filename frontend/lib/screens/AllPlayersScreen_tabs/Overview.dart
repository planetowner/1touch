import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository_provider.dart';
import 'package:onetouch/features/player/player_indicator_value.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_indicators.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/player.dart';

class PlayerOverviewTab extends StatelessWidget {
  const PlayerOverviewTab(
      {super.key, this.player, this.playerId, this.onMatches});
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  final VoidCallback? onMatches;
  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: id,
      builder: (context, detail) {
        final foreground = Theme.of(context).colorScheme.onSurface;
        return SingleChildScrollView(
            key: const ValueKey('player-overview-scroll'),
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                  key: const ValueKey('player-overview-top-block'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: DefaultTextStyle(
                            style: Body1.style.copyWith(color: foreground),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${detail.profile.jerseyNumber ?? '—'}',
                                      style: Heading1.style
                                          .copyWith(color: foreground)),
                                  const SizedBox(height: 4),
                                  Text(detail.currentPosition ?? '—'),
                                  const SizedBox(height: 8),
                                  Text(detail.profile.teamName ?? '—'),
                                  const SizedBox(height: 4),
                                  Text(detail.profile.nationality ?? '—'),
                                ]))),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child:
                            PlayerRemoteImage(detail.profile.image, size: 145))
                  ]),
              const SizedBox(height: 48),
              PlayerBioStatsBlock(
                  player: player, playerId: id, profile: detail.profile),
              const SizedBox(height: 48),
              PlayerSection(
                  title: 'COMPETITION STATS',
                  child: PlayerCompetitionTable(
                      key: const ValueKey('player-competition-stats-card'),
                      competitions: detail.competitions)),
              const SizedBox(height: 48),
              PlayerSection(
                  title: 'MATCHES',
                  trailing: IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'All matches',
                      onPressed: onMatches),
                  child: Column(children: [
                    if (detail.matches.isEmpty)
                      const Text('No appearances this season'),
                    for (final match in detail.matches.take(3))
                      PlayerDetailMatchCard(match: match),
                  ])),
              const SizedBox(height: 48),
              PlayerSection(
                  title: 'CLUB HISTORY',
                  child: PlayerSurface(
                      key: const ValueKey('player-club-history-card'),
                      child: Column(children: [
                        if (detail.clubs.isEmpty)
                          const Text('Club history unavailable'),
                        for (final club in detail.clubs)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(children: [
                                PlayerRemoteImage(club.teamImage),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Text(club.teamName ?? '—',
                                        style: Body2_b.style)),
                                const SizedBox(width: 8),
                                Text(
                                    '${club.startDate?.year ?? '—'}–${club.endDate?.year ?? ''}',
                                    style: Body2.style)
                              ])),
                      ]))),
            ]));
      });
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
        ? 'Compares season rating and share of playing time with expectations '
            "for the player's estimated gross wage, club wage level, league "
            'and position. The two differences carry equal weight. '
            'Fair means within the usual prediction error; higher grades mean '
            'more return for the wage. Transfer fees are not included.'
        : 'Recent performance over the latest 5 league appearances this season, '
            'weighted by playing time and calibrated recency. '
            'Compared with all positions across the five leagues.';
    final season = _indicators?.seasonName;
    final scope =
        season == null ? 'Current season only.' : 'Current season: $season.';
    final evidence = score?.grade == null
        ? switch (score?.unavailableReason) {
            'wage_unavailable' => 'Wage data is unavailable.',
            'no_rated_matches' => 'No rated appearances are available.',
            _ => _failed
                ? 'Could not load the indicators. Tap retry to try again.'
                : 'An indicator is shown when enough data is available.',
          }
        : '${score!.ratedMatches} rated appearances. '
            '${score.referenceCount} players across the five leagues. '
            '${cost ? 'Grades are based on prediction error, not equal-sized groups.' : ''}';
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
          label: 'Height',
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
          label: 'Age',
          value: Text(age == null ? '—' : '$age yrs', style: Heading5.style),
          explanation: null
        ),
        (
          label: 'Form',
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
          label: 'Weight',
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
          label: 'Squad Role',
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
          label: 'Cost-Effectiveness',
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
            child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label, style: Body1.style),
                    if (explanation != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Tooltip(
                          message: explanation!,
                          triggerMode: TooltipTriggerMode.tap,
                          child: const Icon(Icons.help_outline, size: 16),
                        ),
                      ),
                  ],
                ))),
        const SizedBox(height: 10),
        SizedBox(width: double.infinity, height: 22, child: value),
      ],
    );
  }
}
