// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/team.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('search-scaffold'),
      backgroundColor: mainPageBackground(context),
      body: const SafeArea(child: SearchContent()),
    );
  }
}

class SearchContent extends StatefulWidget {
  const SearchContent({super.key});

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;

  static const _tabs = ['ALL', 'PLAYERS', 'TEAMS', 'EVENTS'];
  static const _events = [
    _SearchEvent(
      homeTeamId: 83,
      awayTeamId: 231,
      date: 'Sun, Sep 15',
      time: '10:15 AM',
    ),
    _SearchEvent(
      homeTeamId: 9,
      awayTeamId: 8,
      date: 'Today',
      time: '8:00 PM',
    ),
    _SearchEvent(
      homeTeamId: 14,
      awayTeamId: 18,
      date: 'Sat, Sep 21',
      time: '5:30 PM',
    ),
  ];

  bool get _hasQuery => _searchController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    currentUserPreferences.followedTeamIds.addListener(_onFollowingChanged);
    playerRepository.followedPlayerIds.addListener(_onFollowingChanged);
  }

  void _onFollowingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    currentUserPreferences.followedTeamIds.removeListener(_onFollowingChanged);
    playerRepository.followedPlayerIds.removeListener(_onFollowingChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 24, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    color: colors.onSurface,
                    size: 28,
                  ),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: appColors.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      key: const ValueKey('global-search-field'),
                      controller: _searchController,
                      autofocus: true,
                      maxLines: 1,
                      textInputAction: TextInputAction.search,
                      style: Body1_b.style.copyWith(color: colors.onSurface),
                      cursorColor: colors.onSurface,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle:
                            Body1.style.copyWith(color: colors.onSurface),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        suffixIcon: _hasQuery
                            ? IconButton(
                                tooltip: 'Clear search',
                                icon: Icon(
                                  Icons.close,
                                  color: colors.onSurface,
                                  size: 22,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _selectedIndex = 0);
                                },
                              )
                            : Icon(
                                Icons.search,
                                color: colors.onSurface,
                                size: 28,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _hasQuery ? _buildSearchResults() : _buildRecents(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecents() {
    final recentPlayer = playerRepository.findById('lee-kang-in') ??
        playerRepository.allPlayers.first;

    return ListView(
      key: const ValueKey('search-recents'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        Text(
          'RECENTS',
          style: Heading4.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        _buildPlayerCard(recentPlayer),
        const SizedBox(height: 16),
        _buildTeamCard(mockTeamById(83)),
        const SizedBox(height: 16),
        _buildEventCard(_events.first),
      ],
    );
  }

  Widget _buildSearchResults() {
    return Column(
      key: const ValueKey('search-results'),
      children: [
        SizedBox(
          height: 92,
          child: ListView.separated(
            key: const ValueKey('search-category-tabs'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            itemCount: _tabs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _buildCategoryTab(index),
          ),
        ),
        Expanded(child: _buildSelectedResults()),
      ],
    );
  }

  Widget _buildCategoryTab(int index) {
    final isSelected = _selectedIndex == index;
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      key: ValueKey('search-tab-${_tabs[index].toLowerCase()}'),
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _selectedIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected
              ? appColors.cardBackground
              : appColors.subtleBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          _tabs[index],
          style: Body1_b.style.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }

  Widget _buildSelectedResults() {
    final query = _searchController.text.trim().toLowerCase();
    final players = playerRepository.search(query).take(12).toList();
    final teams = mockTeams
        .where((team) {
          final searchable = [
            team.name,
            team.shortCode ?? '',
            teamLeagueLabel(team.teamId),
          ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .take(12)
        .toList();
    final events = _events.where((event) {
      final home = mockTeamById(event.homeTeamId);
      final away = mockTeamById(event.awayTeamId);
      return '${home.name} ${home.shortCode} ${away.name} ${away.shortCode}'
          .toLowerCase()
          .contains(query);
    }).toList();

    final children = <Widget>[];
    if (_selectedIndex == 0 || _selectedIndex == 1) {
      children.addAll(players.map(_buildPlayerCard));
    }
    if (_selectedIndex == 0 || _selectedIndex == 2) {
      children.addAll(teams.map(_buildTeamCard));
    }
    if (_selectedIndex == 0 || _selectedIndex == 3) {
      children.addAll(events.map(_buildEventCard));
    }

    if (children.isEmpty) {
      return Center(
        child: Text(
          'NO RESULTS',
          key: const ValueKey('search-empty-results'),
          style: Body1_b.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      );
    }

    return ListView.separated(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (_, index) => children[index],
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: AppColors.of(context).cardBackground,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(Player player) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/players/${player.id}'),
      child: Container(
        key: ValueKey('search-player-${player.id}'),
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ClipOval(child: PlayerImage(player: player)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    player.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Heading4.style.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    player.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body1.style.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(Team team) {
    final colors = Theme.of(context).colorScheme;
    final isFollowing =
        currentUserPreferences.followedTeamIds.value.contains(team.teamId);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/team/${team.teamId}'),
      child: Container(
        key: ValueKey('search-team-${team.teamId}'),
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            _buildTeamLogo(team, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Heading4.style.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teamLeagueLabel(team.teamId),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body1.style.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: isFollowing ? 'Unfollow team' : 'Follow team',
              onPressed: () =>
                  currentUserPreferences.toggleFollowedTeam(team.teamId),
              icon: Icon(
                isFollowing ? Icons.star : Icons.star_outline,
                color: colors.onSurface,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(_SearchEvent event) {
    final home = mockTeamById(event.homeTeamId);
    final away = mockTeamById(event.awayTeamId);
    final colors = Theme.of(context).colorScheme;

    return Container(
      key: ValueKey('search-event-${event.homeTeamId}-${event.awayTeamId}'),
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Expanded(child: _buildEventTeam(home)),
          _buildScorePlaceholder(),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    event.date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Body1.style.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.time,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Body1.style.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ),
          _buildScorePlaceholder(),
          Expanded(child: _buildEventTeam(away)),
        ],
      ),
    );
  }

  Widget _buildTeamLogo(Team team, {required double size}) {
    final path = team.imagePath;
    final fallback = Icon(
      Icons.shield_outlined,
      color: Theme.of(context).colorScheme.onSurface,
      size: size * 0.7,
    );

    if (path == null || path.isEmpty) {
      return SizedBox(width: size, height: size, child: fallback);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildEventTeam(Team team) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTeamLogo(team, size: 44),
        const SizedBox(height: 6),
        Text(
          team.shortCode ?? team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Body2.style.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildScorePlaceholder() {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '#',
        style: Heading4.style.copyWith(color: colors.onSurface),
      ),
    );
  }
}

class _SearchEvent {
  const _SearchEvent({
    required this.homeTeamId,
    required this.awayTeamId,
    required this.date,
    required this.time,
  });

  final int homeTeamId;
  final int awayTeamId;
  final String date;
  final String time;
}
