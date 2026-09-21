import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository_provider.dart';
import 'package:onetouch/features/player/player_indicator_value.dart';
import 'package:onetouch/models/player_indicators.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/match_card.dart';

class PlayerOverviewTab extends StatelessWidget {
  final Player player;

  const PlayerOverviewTab({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Content on top of background
        SingleChildScrollView(
          key: const ValueKey('player-overview-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBlock(context, player),
              const SizedBox(height: 48),
              _buildBioStatsBlock(context),
              const SizedBox(height: 48),
              _buildCompetitionsBlock(context),
              const SizedBox(height: 48),
              _buildMatchSummaryBlock(context),
              const SizedBox(height: 48),
              _buildClubHistoryBlock(context),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBlock(BuildContext context, Player player) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Row(
      key: const ValueKey('player-overview-top-block'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${player.jerseyNumber}',
              style: Heading1.style.copyWith(color: foreground),
            ),
            const SizedBox(height: 4),
            Text(
              player.positionLabel,
              style: Body1.style.copyWith(color: foreground),
            ),
            const SizedBox(height: 8),
            Text(
              player.teamName,
              style: Body1.style.copyWith(color: foreground),
            ),
            const SizedBox(height: 4),
            Text(
              '${player.nationality} ${player.nationalityFlag}',
              style: Body1.style.copyWith(color: foreground),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: 145,
          height: 145,
          child: PlayerImage(
            player: player,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  Widget _buildBioStatsBlock(BuildContext context) {
    return PlayerBioStatsBlock(player: player);
  }

  Widget _buildCompetitionsBlock(BuildContext context) {
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppPalette.darkGrey : AppPalette.white;
    final badgeColor =
        isDark ? const Color(0xFF3D3D3D) : appColors.subtleBackground;
    final season = player.seasonStats;
    final winRate = (52 + player.rankingScore % 30).round();
    final competitions = [
      {
        "name": player.leagueCode,
        "mp": "${season.appearances}",
        "wr": "$winRate%",
        "rating": season.rating.toStringAsFixed(1),
      },
      {
        "name": "UCL",
        "mp": "${(season.appearances * 0.30).round()}",
        "wr": "${(winRate - 3).clamp(0, 100)}%",
        "rating": (season.rating - 0.1).toStringAsFixed(1),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("COMPETITION STATS", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-competition-stats-card'),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        "League",
                        style: Body2.style.copyWith(
                          color: appColors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "MP",
                        textAlign: TextAlign.center,
                        style: Body2.style.copyWith(
                          color: appColors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "WR",
                        textAlign: TextAlign.center,
                        style: Body2.style.copyWith(
                          color: appColors.mutedForeground,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        "Rating",
                        textAlign: TextAlign.right,
                        style: Body2.style.copyWith(
                          color: appColors.mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: appColors.divider, height: 1),
              // Stat rows
              ...competitions.asMap().entries.map((entry) {
                final comp = entry.value;
                final isLast = entry.key == competitions.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(comp["name"]!, style: Heading5.style),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              comp["mp"]!,
                              textAlign: TextAlign.center,
                              style: Heading5.style,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              comp["wr"]!,
                              textAlign: TextAlign.center,
                              style: Heading5.style,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  comp["rating"]!,
                                  style: Heading5.style,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) Divider(color: appColors.divider, height: 1),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchSummaryBlock(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final matches = playerRepository.recentMatchesFor(player.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("MATCHES", style: Body2_b.style),
            Icon(Icons.chevron_right, color: foreground, size: 20),
          ],
        ),
        const SizedBox(height: 16),
        // Each match is its own card (shared with the Matches tab).
        ...matches.map((match) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PlayerMatchCard(
              result: match.result,
              score: match.score,
              competition: match.competition,
              againstLogo: match.opponentLogoAsset,
              stats: [
                {'label': 'Goal', 'value': '${match.goals}'},
                {'label': 'Assist', 'value': '${match.assists}'},
                {'label': 'Pass', 'value': '${match.passes}'},
              ],
              rating: match.rating.toStringAsFixed(1),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildClubHistoryBlock(BuildContext context) {
    final history = player.clubHistory;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppPalette.darkGrey : AppPalette.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("CLUB HISTORY", style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('player-club-history-card'),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: history.map((club) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Team logo
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: club.logoAsset == null
                                ? Icon(
                                    Icons.shield_outlined,
                                    color: appColors.mutedForeground,
                                  )
                                : Image.asset(
                                    club.logoAsset!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Club name
                        Expanded(child: Text(club.club, style: Heading5.style)),
                        // Year
                        Text(club.seasonLabel, style: Body1.style),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class PlayerBioStatsBlock extends StatefulWidget {
  final Player player;
  final PlayerIndicatorsRepository? repository;

  const PlayerBioStatsBlock({super.key, required this.player, this.repository});

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
    if (oldWidget.player.externalPlayerId != widget.player.externalPlayerId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    final requestId = ++_requestId;
    final playerId = widget.player.externalPlayerId;
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

  _PlayerInfo _indicatorInfo({required bool cost}) => _PlayerInfo(
        label: cost ? 'Cost-Effectiveness' : 'Form',
        explanation: cost ? _explanation(cost: true) : null,
        valueWidget: PlayerIndicatorValue(
          key: ValueKey(cost ? 'player-cost-effectiveness' : 'player-form'),
          score: cost ? _indicators?.costEffectiveness : _indicators?.form,
          loading: _loading,
          failed: _failed,
          explanation: _explanation(cost: cost),
          onRetry: () => setState(_load),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppPalette.darkGrey : AppPalette.white;
    final birthDate = DateTime.parse(player.dateOfBirth);
    final now = DateTime.now();
    final age = now.year -
        birthDate.year -
        ((now.month < birthDate.month ||
                (now.month == birthDate.month && now.day < birthDate.day))
            ? 1
            : 0);
    final columns = [
      [
        _PlayerInfo(label: 'Height', value: '${player.heightCm}cm'),
        _PlayerInfo(label: 'Age', value: '$age yrs'),
        _indicatorInfo(cost: false),
      ],
      [
        _PlayerInfo(label: 'Weight', value: '${player.weightKg}kg'),
        _PlayerInfo(
          label: 'Squad Role',
          valueWidget: PlayerIndicatorValue(
            key: const ValueKey('player-squad-role'),
            label: _indicators?.squadRole,
            loading: _loading,
            failed: _failed,
            explanation:
                'Based on league playing time while available at this club, '
                'excluding recorded injuries and suspensions. '
                'Prospect means low usage and age 21 or younger when calculated. '
                'Updated after completed league matches.',
            onRetry: () => setState(_load),
          ),
        ),
        _indicatorInfo(cost: true),
      ],
    ];

    return Container(
      key: const ValueKey('player-bio-stats-card'),
      decoration: BoxDecoration(
        color: cardColor,
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
                    _PlayerInfoCell(info: columns[columnIndex][itemIndex]),
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

class _PlayerInfo {
  const _PlayerInfo({
    required this.label,
    this.value,
    this.valueWidget,
    this.explanation,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final String? explanation;
}

class _PlayerInfoCell extends StatelessWidget {
  const _PlayerInfoCell({required this.info});

  final _PlayerInfo info;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 18,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  info.label,
                  key: ValueKey('player-info-label-${info.label}'),
                  style: Body1.style.copyWith(color: foreground),
                ),
                if (info.explanation != null) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: info.explanation!,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(
                      Icons.help_outline,
                      size: 18,
                      color: foreground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 22,
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: info.valueWidget ?? Text(info.value!, style: Heading5.style),
          ),
        ),
      ],
    );
  }
}
