// ignore_for_file: file_names

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onetouch/core/season_label.dart';
import 'package:onetouch/core/display_preferences.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository_provider.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/players/player_indicators_repository.dart';
import 'package:onetouch/data/players/player_indicators_repository_provider.dart';
import 'package:onetouch/features/player/player_indicator_value.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player_indicators.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/team_contract_roster.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/l10n/app_localizations.dart';

String? _countryFlagEmoji(String? rawCode) {
  final code = rawCode?.trim().toUpperCase();
  final subdivision = switch (code) {
    'GB-ENG' => 'gbeng',
    'GB-SCT' => 'gbsct',
    'GB-WLS' => 'gbwls',
    _ => null,
  };
  if (subdivision != null) {
    // 영국 구성국 국기는 국가 코드 두 글자가 아닌 태그 시퀀스를 사용해요.
    return String.fromCharCodes([
      0x1F3F4,
      ...subdivision.codeUnits.map((unit) => 0xE0000 + unit),
      0xE007F,
    ]);
  }
  if (code == null || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return null;
  return String.fromCharCodes([
    for (final unit in code.codeUnits) 0x1F1E6 + unit - 0x41,
  ]);
}

String? _countryFlagImageUrl(String? rawCode, String? fallback) {
  final code = rawCode?.trim().toUpperCase();
  if (code != null &&
      (RegExp(r'^[A-Z]{2}$').hasMatch(code) ||
          const {'GB-ENG', 'GB-SCT', 'GB-WLS', 'GB-NIR'}.contains(code))) {
    return 'https://flagcdn.com/48x36/${code.toLowerCase()}.png';
  }
  return fallback?.trim().isNotEmpty == true ? fallback!.trim() : null;
}

class _PlayerCountryLabel extends StatelessWidget {
  const _PlayerCountryLabel({required this.profile});

  final PlayerDetailProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = countryNameLabel(
      context,
      profile.nationalityId,
      profile.nationality ?? '—',
    );
    final emoji = defaultTargetPlatform == TargetPlatform.iOS
        ? _countryFlagEmoji(profile.nationalityCode)
        : null;
    if (emoji != null) {
      return Text(
        '$name $emoji',
        key: const ValueKey('player-overview-country'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final imageUrl = _countryFlagImageUrl(
      profile.nationalityCode,
      profile.nationalityImage,
    );
    if (imageUrl == null) {
      return Text(
        name,
        key: const ValueKey('player-overview-country'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Row(
      key: const ValueKey('player-overview-country'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 2),
        CachedNetworkImage(
          imageUrl: imageUrl,
          width: 16,
          height: 12,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(width: 16, height: 12),
          errorWidget: (_, __, ___) => const SizedBox(width: 16, height: 12),
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
        ),
      ],
    );
  }
}

class PlayerOverviewTab extends StatelessWidget {
  const PlayerOverviewTab(
      {super.key,
      this.player,
      this.playerId,
      this.contractRepository,
      this.onMatches,
      this.onTopBlockHeightChanged});
  final Player? player;
  final int? playerId;
  final TeamContractRepository? contractRepository;
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
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
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
                                  _PlayerCountryLabel(profile: detail.profile),
                                  const SizedBox(height: 16),
                                ],
                              ))),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: ShaderMask(
                                key: const ValueKey(
                                    'player-overview-image-bottom-fade'),
                                blendMode: BlendMode.dstIn,
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [0, 0.78, 1],
                                ).createShader(bounds),
                                child: PlayerRemoteImage.portrait(
                                  detail.profile.image,
                                  key: const ValueKey('player-overview-image'),
                                  width: 160,
                                ),
                              ),
                            ),
                            if (detail.profile.teamId case final teamId?)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: _PlayerLeadershipBadge(
                                  teamId: teamId,
                                  playerId: detail.playerId,
                                  repository: contractRepository,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              PlayerBioStatsBlock(
                  player: player,
                  playerId: id,
                  profile: detail.profile,
                  initialIndicators: detail.currentIndicators),
              const SizedBox(height: 48),
              PlayerSection(
                  title: tr(context, 'COMPETITION STATS'),
                  child: PlayerCompetitionTable(
                    key: const ValueKey('player-competition-stats-card'),
                    competitions: detail.competitions,
                  )),
              const SizedBox(height: 48),
              PlayerSection(
                  title: trUpper(context, 'Matches'),
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
              const SizedBox(height: 32),
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

class _PlayerLeadershipBadge extends StatefulWidget {
  const _PlayerLeadershipBadge({
    required this.teamId,
    required this.playerId,
    this.repository,
  });

  final int teamId;
  final int playerId;
  final TeamContractRepository? repository;

  @override
  State<_PlayerLeadershipBadge> createState() => _PlayerLeadershipBadgeState();
}

class _PlayerLeadershipBadgeState extends State<_PlayerLeadershipBadge> {
  late Future<TeamContractRoster> _roster;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_PlayerLeadershipBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.repository != widget.repository) {
      _load();
    }
  }

  void _load() {
    _roster = Future.sync(
        () => (widget.repository ?? teamContractRepository).loadForTeam(
              widget.teamId,
              seasonId: footballCatalog.resolve(widget.teamId)?.seasonId,
            ));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TeamContractRoster>(
      future: _roster,
      builder: (context, snapshot) {
        TeamLeadershipRole? role;
        for (final player in snapshot.data?.players ?? <TeamPlayerContract>[]) {
          if (player.playerId == widget.playerId) {
            role = player.leadershipRole;
            break;
          }
        }
        if (role == null) return const SizedBox.shrink();

        final color = Theme.of(context).brightness == Brightness.dark
            ? AppPalette.white
            : AppPalette.black;
        final isCaptain = role == TeamLeadershipRole.captain;
        return Container(
          key: ValueKey(
              'player-overview-leadership-${isCaptain ? 'captain' : 'vice-captain'}'),
          width: 24,
          height: 18,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: color)),
          child: Text(
            isCaptain ? 'C' : 'VC',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: Body2_b.style.copyWith(color: color, height: 1.3),
          ),
        );
      },
    );
  }
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
  final PlayerIndicators? initialIndicators;

  const PlayerBioStatsBlock({
    super.key,
    this.player,
    this.playerId,
    this.repository,
    this.profile,
    this.initialIndicators,
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
        oldWidget.repository != widget.repository ||
        oldWidget.initialIndicators != widget.initialIndicators) {
      _load();
    }
  }

  void _load() {
    final requestId = ++_requestId;
    final playerId = widget.id;
    // 상세 응답과 캐시에 함께 받은 지표는 기본 정보와 같은 프레임에 보여줘요.
    _indicators = widget.initialIndicators;
    _failed = false;
    _loading = _indicators == null && playerId != null;
    if (_loading) unawaited(_fetch(playerId!, requestId));
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
  Widget build(BuildContext context) =>
      ValueListenableBuilder<DisplayPreferences>(
        valueListenable: appDisplayPreferences,
        builder: (context, preferences, _) =>
            _buildStats(context, preferences.unit),
      );

  Widget _buildStats(BuildContext context, MeasurementUnit unit) {
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
              unit.formatHeight(widget.profile == null
                  ? player?.heightCm
                  : widget.profile!.heightCm),
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
              unit.formatWeight(widget.profile == null
                  ? player?.weightKg
                  : widget.profile!.weightKg),
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
                          'Measured by comparing actual salary against 1touch’s predicted market value based on performance and playtime.',
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
