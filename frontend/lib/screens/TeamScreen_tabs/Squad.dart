import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository_provider.dart';
import 'package:onetouch/data/seasons/season_repository_provider.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/features/team/squad/squad_player_presentation.dart';
import 'package:onetouch/models/season.dart';
import 'package:onetouch/models/team_contract_roster.dart';
import 'package:onetouch/l10n/app_localizations.dart';

// TODO(squad-api): Remove after the API-backed Squad screen is confirmed on
// device. It is intentionally not used as an error fallback because that would
// hide authentication, transport, or response-contract failures.
// ignore: unused_element
List<SquadPlayer> _mockSquad() => [
      // Goalkeepers
      SquadPlayer(
          id: 1,
          name: 'Kim Seung-gyu',
          teamLabel: 'Jeonbuk • 1',
          jerseyNumber: 1,
          position: Position.GK,
          age: 35,
          contractEndYear: 2025),
      SquadPlayer(
          id: 2,
          name: 'Park Jun-hyuk',
          teamLabel: 'Jeonbuk • 31',
          jerseyNumber: 31,
          position: Position.GK,
          age: 24,
          contractEndYear: 2027),
      SquadPlayer(
          id: 3,
          name: 'Lee Chang-geun',
          teamLabel: 'Jeonbuk • 41',
          jerseyNumber: 41,
          position: Position.GK,
          age: 21,
          contractEndYear: 2026),

      // Defenders
      SquadPlayer(
          id: 4,
          name: 'Hong Jeong-ho',
          teamLabel: 'Jeonbuk • 4',
          jerseyNumber: 4,
          position: Position.DF,
          age: 34,
          contractEndYear: 2025),
      SquadPlayer(
          id: 5,
          name: 'Choi Bo-kyung',
          teamLabel: 'Jeonbuk • 5',
          jerseyNumber: 5,
          position: Position.DF,
          age: 29,
          contractEndYear: 2026),
      SquadPlayer(
          id: 6,
          name: 'Kim Jin-su',
          teamLabel: 'Jeonbuk • 13',
          jerseyNumber: 13,
          position: Position.DF,
          age: 31,
          contractEndYear: 2026),
      SquadPlayer(
          id: 7,
          name: 'Lee Yong',
          teamLabel: 'Jeonbuk • 2',
          jerseyNumber: 2,
          position: Position.DF,
          age: 36,
          contractEndYear: 2025),
      SquadPlayer(
          id: 8,
          name: 'Gu Ja-ryong',
          teamLabel: 'Jeonbuk • 3',
          jerseyNumber: 3,
          position: Position.DF,
          age: 27,
          contractEndYear: 2027),
      SquadPlayer(
          id: 9,
          name: 'Park Jin-seop',
          teamLabel: 'Jeonbuk • 23',
          jerseyNumber: 23,
          position: Position.DF,
          age: 23,
          contractEndYear: 2028),
      SquadPlayer(
          id: 10,
          name: 'Shin Hyung-min',
          teamLabel: 'Jeonbuk • 15',
          jerseyNumber: 15,
          position: Position.DF,
          age: 26,
          contractEndYear: 2027),
      SquadPlayer(
          id: 11,
          name: 'Kim Tae-hyun',
          teamLabel: 'Jeonbuk • 33',
          jerseyNumber: 33,
          position: Position.DF,
          age: 22,
          contractEndYear: 2026),

      // Midfielders
      SquadPlayer(
          id: 12,
          name: 'Baek Seung-ho',
          teamLabel: 'Jeonbuk • 6',
          jerseyNumber: 6,
          position: Position.MF,
          age: 30,
          contractEndYear: 2026),
      SquadPlayer(
          id: 13,
          name: 'Han Kyo-won',
          teamLabel: 'Jeonbuk • 8',
          jerseyNumber: 8,
          position: Position.MF,
          age: 28,
          contractEndYear: 2025),
      SquadPlayer(
          id: 14,
          name: 'Moon Seon-min',
          teamLabel: 'Jeonbuk • 7',
          jerseyNumber: 7,
          position: Position.MF,
          age: 32,
          contractEndYear: 2025),
      SquadPlayer(
          id: 15,
          name: 'Son Jun-ho',
          teamLabel: 'Jeonbuk • 10',
          jerseyNumber: 10,
          position: Position.MF,
          age: 33,
          contractEndYear: 2026),
      SquadPlayer(
          id: 16,
          name: 'Jeong Hyeok',
          teamLabel: 'Jeonbuk • 16',
          jerseyNumber: 16,
          position: Position.MF,
          age: 25,
          contractEndYear: 2027),
      SquadPlayer(
          id: 17,
          name: 'Lee Seung-gi',
          teamLabel: 'Jeonbuk • 22',
          jerseyNumber: 22,
          position: Position.MF,
          age: 24,
          contractEndYear: 2028),
      SquadPlayer(
          id: 18,
          name: 'Kim Bo-kyung',
          teamLabel: 'Jeonbuk • 26',
          jerseyNumber: 26,
          position: Position.MF,
          age: 35,
          contractEndYear: 2025),
      SquadPlayer(
          id: 19,
          name: 'Park Chan-ul',
          teamLabel: 'Jeonbuk • 28',
          jerseyNumber: 28,
          position: Position.MF,
          age: 20,
          contractEndYear: 2027),

      // Forwards
      SquadPlayer(
          id: 20,
          name: 'Cho Gue-sung',
          teamLabel: 'Jeonbuk • 9',
          jerseyNumber: 9,
          position: Position.FW,
          age: 25,
          contractEndYear: 2027),
      SquadPlayer(
          id: 21,
          name: 'Gustav Wikheim',
          teamLabel: 'Jeonbuk • 11',
          jerseyNumber: 11,
          position: Position.FW,
          age: 30,
          contractEndYear: 2026),
      SquadPlayer(
          id: 22,
          name: 'Stanislav Iljutcenko',
          teamLabel: 'Jeonbuk • 17',
          jerseyNumber: 17,
          position: Position.FW,
          age: 34,
          contractEndYear: 2025),
      SquadPlayer(
          id: 23,
          name: 'Lee Dong-jun',
          teamLabel: 'Jeonbuk • 19',
          jerseyNumber: 19,
          position: Position.FW,
          age: 23,
          contractEndYear: 2028),
      SquadPlayer(
          id: 24,
          name: 'Kim In-sung',
          teamLabel: 'Jeonbuk • 29',
          jerseyNumber: 29,
          position: Position.FW,
          age: 21,
          contractEndYear: 2027),
      SquadPlayer(
          id: 25,
          name: 'Park Sang-hyuk',
          teamLabel: 'Jeonbuk • 37',
          jerseyNumber: 37,
          position: Position.FW,
          age: 19,
          contractEndYear: 2028),
    ];

class SquadTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final TeamContractRepository? contractRepository;

  const SquadTab({
    super.key,
    required this.team,
    this.contractRepository,
  });

  @override
  State<SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<SquadTab> {
  List<SquadPlayer> _players = [];
  bool _isLoading = true;
  SortOption _sortOption = SortOption.position;
  bool _isAscending = true;
  int? _selectedSeasonId;
  bool? _rosterIsCurrent;
  Object? _loadError;
  int _loadRequestId = 0;

  TeamContractRepository get _repository =>
      widget.contractRepository ?? teamContractRepository;

  static const List<Position?> _positionOrder = [
    Position.GK,
    Position.DF,
    Position.MF,
    Position.FW,
    null,
  ];

  String _positionLabel(Position? pos) {
    switch (pos) {
      case Position.GK:
        return tr(context, 'GOALKEEPER');
      case Position.DF:
        return tr(context, 'DEFENDERS');
      case Position.MF:
        return tr(context, 'MIDFIELDERS');
      case Position.FW:
        return tr(context, 'ATTACKERS');
      case null:
        return tr(context, 'POSITION UNAVAILABLE');
    }
  }

  int _compare(SquadPlayer a, SquadPlayer b) {
    return compareSquadPlayers(
      a,
      b,
      option: _sortOption,
      ascending: _isAscending,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectDefaultSeason();
    _startRosterLoad(updateState: false);
  }

  @override
  void didUpdateWidget(SquadTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.team?['id'] != widget.team?['id'] ||
        oldWidget.contractRepository != widget.contractRepository) {
      _selectDefaultSeason();
      _startRosterLoad();
    }
  }

  List<Season> get _availableSeasons {
    final teamId = widget.team?['id'] as int?;
    if (teamId == null) return const [];
    final seasonIds = footballCatalog.memberships
        // 계약 API는 Big 5 정규리그 시즌만 받아요. 컵 소속 시즌은 제외해요.
        .where((membership) =>
            membership.teamId == teamId &&
            TeamPageEligibility.domesticBigFiveCompetitionIds
                .contains(membership.competitionId))
        .map((membership) => membership.seasonId)
        .toSet();
    final seasons = seasonRepository.allSeasons
        .where((season) => seasonIds.contains(season.seasonId))
        .toList();
    seasons.sort((a, b) {
      if (a.isCurrent != b.isCurrent) return a.isCurrent ? -1 : 1;
      return b.name.compareTo(a.name);
    });
    return seasons;
  }

  void _selectDefaultSeason() {
    final seasons = _availableSeasons;
    _selectedSeasonId = seasons.isEmpty ? null : seasons.first.seasonId;
  }

  Season? get _selectedSeason {
    final selectedId = _selectedSeasonId;
    if (selectedId == null) return null;
    return seasonRepository.findById(selectedId);
  }

  bool get _isCurrentSeason =>
      _rosterIsCurrent ?? _selectedSeason?.isCurrent ?? true;

  String _seasonLabel(Season season) {
    final years = season.name.split('/');
    if (years.length != 2) return season.name;
    String shortYear(String value) =>
        value.length > 2 ? value.substring(value.length - 2) : value;
    return '${shortYear(years[0])}/${shortYear(years[1])}';
  }

  void _selectSeason(Season season) {
    setState(() {
      _selectedSeasonId = season.seasonId;
      if (!season.isCurrent && _sortOption == SortOption.contractLength) {
        _sortOption = SortOption.position;
      }
    });
    _startRosterLoad();
  }

  void _startRosterLoad({bool updateState = true}) {
    final requestId = ++_loadRequestId;
    final teamId = widget.team?['id'] as int?;
    final teamName = widget.team?['name'] as String?;
    final seasonId = _selectedSeasonId;
    // The API requires an explicit season for teams without a current Big 5
    // context. Until the backend exposes team-season options, only request a
    // roster when the frontend has a verified membership season.
    final validTeam = teamId != null &&
        teamName != null &&
        teamName.isNotEmpty &&
        seasonId != null;
    final cached = validTeam
        ? _repository.cachedForTeam(teamId, seasonId: seasonId)
        : null;

    void prepare() {
      _players = cached == null
          ? const []
          : _presentPlayers(cached.players, teamId!, teamName!, DateTime.now());
      _rosterIsCurrent = cached?.isCurrent;
      _isLoading = validTeam && cached == null;
      _loadError = null;
    }

    if (updateState) {
      setState(prepare);
    } else {
      prepare();
    }

    if (validTeam) {
      unawaited(_loadRoster(
        requestId: requestId,
        teamId: teamId,
        teamName: teamName,
        seasonId: seasonId,
      ));
    }
  }

  Future<void> _loadRoster({
    required int requestId,
    required int teamId,
    required String teamName,
    required int? seasonId,
  }) async {
    try {
      final roster = await _repository.loadForTeam(
        teamId,
        seasonId: seasonId,
      );
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _players =
            _presentPlayers(roster.players, teamId, teamName, DateTime.now());
        _rosterIsCurrent = roster.isCurrent;
        _isLoading = false;
        _loadError = null;
        if (!roster.isCurrent && _sortOption == SortOption.contractLength) {
          _sortOption = SortOption.position;
        }
      });
    } on Object catch (error) {
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _isLoading = false;
        if (_players.isEmpty) _loadError = error;
      });
    }
  }

  List<SquadPlayer> _presentPlayers(
    List<TeamPlayerContract> contracts,
    int teamId,
    String teamName,
    DateTime asOf,
  ) {
    return contracts
        .map((contract) => SquadPlayer.fromContract(
              contract,
              teamName: teamName,
              teamId: teamId,
              asOf: asOf,
            ))
        .toList(growable: false);
  }

  void _retryLoad() {
    _startRosterLoad();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    if (_loadError != null && _players.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'Unable to load squad'),
              key: const ValueKey('squad-error'),
              style: Body1.style,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('squad-retry'),
              onPressed: _retryLoad,
              child: Text(tr(context, 'Retry')),
            ),
          ],
        ),
      );
    }
    if (_players.isEmpty) {
      return Center(
        child: Text(
          tr(context, 'No players found'),
          key: const ValueKey('squad-empty'),
          style: TextStyle(color: AppColors.of(context).mutedForeground),
        ),
      );
    }

    // Group & sort
    if (_sortOption == SortOption.position) {
      final grouped = <Position?, List<SquadPlayer>>{};
      for (final p in _players) {
        grouped.putIfAbsent(p.position, () => []).add(p);
      }
      for (final group in grouped.values) {
        group.sort(_compare);
      }

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          _filterRow(),
          ..._positionOrder
              .where((pos) => grouped.containsKey(pos))
              .expand((pos) => [
                    const SizedBox(height: 24),
                    _PositionHeader(
                      key: ValueKey(
                        'squad-position-${pos?.name ?? 'unavailable'}-header',
                      ),
                      label: _positionLabel(pos),
                    ),
                    const SizedBox(height: 16),
                    _PlayerGrid(
                      key: ValueKey(
                        'squad-position-${pos?.name ?? 'unavailable'}-grid',
                      ),
                      players: grouped[pos]!,
                    ),
                  ]),
        ],
      );
    }
    final sorted = [..._players]..sort(_compare);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        _filterRow(),
        const SizedBox(height: 24),
        _PlayerGrid(players: sorted),
      ],
    );
  }

  Widget _filterRow() {
    return Row(
      key: const ValueKey('squad-filter-row'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _seasonDropdown()),
        const SizedBox(width: 12),
        Expanded(child: _sortDropdown()),
      ],
    );
  }

  Widget _seasonDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seasons = _availableSeasons;
    final selectedSeason = _selectedSeason;
    if (selectedSeason == null || seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    final background = isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return AppDropdown<int>(
      key: const ValueKey('squad-season-dropdown'),
      triggerKey: const ValueKey('squad-season-trigger'),
      value: selectedSeason.seasonId,
      backgroundColor: background,
      foregroundColor: foreground,
      textStyle: Body2_b.style,
      options: seasons
          .map(
            (season) => AppDropdownOption<int>(
              value: season.seasonId,
              label: _seasonLabel(season),
              optionKey: ValueKey(
                'squad-season-option-${season.seasonId}',
              ),
            ),
          )
          .toList(),
      onChanged: (seasonId) {
        final season = seasons.firstWhere((item) => item.seasonId == seasonId);
        _selectSeason(season);
      },
    );
  }

  Widget _sortDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final sortOptions = availableSquadSortOptions(isCurrent: _isCurrentSeason);

    return AppDropdown<String>(
      key: const ValueKey('squad-sort-dropdown'),
      triggerKey: const ValueKey('squad-sort-trigger'),
      chevronKey: const ValueKey('squad-sort-arrow'),
      value: null,
      selectedLabel: tr(context, _sortOption.label).toUpperCase(),
      backgroundColor: background,
      foregroundColor: foreground,
      textStyle: Body2_b.style,
      options: [
        AppDropdownOption<String>(
          value: 'direction-ascending',
          label: tr(context, 'ASCENDING'),
          optionKey: const ValueKey('squad-sort-option-ascending'),
          selected: _isAscending,
          selectedIconKey: ValueKey(
            'squad-sort-selected-icon-${tr(context, 'ASCENDING')}',
          ),
        ),
        AppDropdownOption<String>(
          value: 'direction-descending',
          label: tr(context, 'DESCENDING'),
          optionKey: const ValueKey('squad-sort-option-descending'),
          selected: !_isAscending,
          selectedIconKey: ValueKey(
            'squad-sort-selected-icon-${tr(context, 'DESCENDING')}',
          ),
        ),
        for (var index = 0; index < sortOptions.length; index++)
          AppDropdownOption<String>(
            value: 'sort-${sortOptions[index].name}',
            label: tr(context, sortOptions[index].label).toUpperCase(),
            optionKey: ValueKey(
              'squad-sort-option-${sortOptions[index].name}',
            ),
            selected: _sortOption == sortOptions[index],
            dividerBefore: index == 0,
            selectedIconKey: ValueKey(
              'squad-sort-selected-icon-${sortOptions[index].label.toUpperCase()}',
            ),
          ),
      ],
      onChanged: (value) {
        setState(() {
          if (value == 'direction-ascending') {
            _isAscending = true;
          } else if (value == 'direction-descending') {
            _isAscending = false;
          } else {
            final name = value.substring('sort-'.length);
            _sortOption = sortOptions.firstWhere(
              (option) => option.name == name,
            );
          }
        });
      },
    );
  }
}

class _PositionHeader extends StatelessWidget {
  final String label;

  const _PositionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      tr(context, label),
      style: Body2_b.style,
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  final List<SquadPlayer> players;

  const _PlayerGrid({super.key, required this.players});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 330 / 420,
      ),
      itemBuilder: (context, index) => _PlayerCard(player: players[index]),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final SquadPlayer player;

  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    return Semantics(
      button: true,
      label: tr(context, 'Open {name}',
          {'name': playerNameLabel(context, player.id, player.name)}),
      child: InkWell(
        key: ValueKey('squad-player-link-${player.id}'),
        onTap: () => openPlayerPage(context, player.id.toString()),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: ValueKey('squad-player-card-${player.id}'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  key: ValueKey('squad-player-image-panel-${player.id}'),
                  flex: 4,
                  child: Stack(
                    children: [
                      // Background + image fills entire area
                      Container(
                        width: double.infinity,
                        color: appColors.cardBackground,
                      ),

                      // Playerimage
                      Positioned(
                        right: 10,
                        left: 50,
                        top: 16,
                        bottom: 0,
                        child: player.imageUrl != null
                            ? Image.network(
                                player.imageUrl!,
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                                errorBuilder: (_, __, ___) => Image.asset(
                                  'assets/player_comparison/player_placeholder.png',
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                ),
                              )
                            : Image.asset(
                                'assets/player_comparison/player_placeholder.png',
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomCenter,
                              ),
                      ),

                      if (player.jerseyNumber != null)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Text(
                            '${player.jerseyNumber}',
                            key: ValueKey('squad-jersey-number-${player.id}'),
                            style: Heading2.style,
                          ),
                        ),

                      if (player.leadershipRole != null)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: _LeadershipBadge(
                            playerId: player.id,
                            role: player.leadershipRole!,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    color: appColors.subtleBackground,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            playerNameLabel(context, player.id, player.name),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Heading5.style,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeadershipBadge extends StatelessWidget {
  const _LeadershipBadge({
    required this.playerId,
    required this.role,
  });

  final int playerId;
  final TeamLeadershipRole role;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.white
        : AppPalette.black;
    final label = role == TeamLeadershipRole.captain ? 'C' : 'VC';
    final roleName =
        role == TeamLeadershipRole.captain ? 'captain' : 'vice-captain';

    return Container(
      key: ValueKey('squad-leadership-$roleName-$playerId'),
      width: 24,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.center,
        overflow: TextOverflow.visible,
        style: Body2_b.style.copyWith(color: color, height: 1.3),
      ),
    );
  }
}
