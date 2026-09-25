// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/search/search_repository.dart' as search_data;
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart'
    as team_providers;
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class Search extends StatelessWidget {
  const Search({
    super.key,
    this.preferences,
    this.competitionContextResolver,
    this.repository,
  });

  final CurrentUserPreferences? preferences;
  final TeamCompetitionContextResolver? competitionContextResolver;
  final search_data.SearchRepository? repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('search-scaffold'),
      backgroundColor: mainPageBackground(context),
      body: SafeArea(
        child: SearchContent(
          preferences: preferences ?? currentUserPreferences,
          competitionContextResolver: competitionContextResolver ??
              team_providers.teamCompetitionContextResolver,
          repository: repository ?? search_data.searchRepository,
        ),
      ),
    );
  }
}

class SearchContent extends StatefulWidget {
  const SearchContent({
    super.key,
    required this.preferences,
    required this.competitionContextResolver,
    required this.repository,
  });

  final CurrentUserPreferences preferences;
  final TeamCompetitionContextResolver competitionContextResolver;
  final search_data.SearchRepository repository;

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  bool _isSearching = false;
  Object? _searchError;
  int _generation = 0;
  Timer? _debounce;
  search_data.SearchResults _results = const search_data.SearchResults();

  static const _tabs = ['ALL', 'PLAYERS', 'TEAMS', 'EVENTS'];
  bool get _hasQuery => _searchController.text.trim().isNotEmpty;
  TeamPageEligibility get _teamPageEligibility =>
      TeamPageEligibility(widget.competitionContextResolver);

  @override
  void initState() {
    super.initState();
    widget.preferences.followedTeamIds.addListener(_onFollowingChanged);
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    ++_generation;
    setState(() {
      _results = const search_data.SearchResults();
      _searchError = null;
      _isSearching = _hasQuery;
    });
    if (_hasQuery)
      _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _search() async {
    final generation = ++_generation;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await widget.repository.search(_searchController.text);
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _searchError = error;
        _isSearching = false;
      });
    }
  }

  void _onFollowingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleTeam(int id) async {
    try {
      await widget.preferences.toggleFollowedTeam(id);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tr(context,
                'Unable to update followed teams. Please try again.'))));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.preferences.followedTeamIds.removeListener(_onFollowingChanged);
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
                  tooltip: tr(context, 'Back'),
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
                      maxLength: 100,
                      onChanged: (_) => _onQueryChanged(),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: tr(context, 'Search...'),
                        hintStyle:
                            Body1.style.copyWith(color: colors.onSurface),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 18,
                        ),
                        suffixIcon: _hasQuery
                            ? IconButton(
                                tooltip: tr(context, 'Clear search'),
                                icon: Icon(
                                  Icons.close,
                                  color: colors.onSurface,
                                  size: 22,
                                ),
                                onPressed: () {
                                  _searchController.clear();
                                  _selectedIndex = 0;
                                  _onQueryChanged();
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
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchError != null) {
      return Center(
        key: const ValueKey('search-load-error'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'SEARCH UNAVAILABLE'),
              style: Body1_b.style.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _search,
              child: Text(tr(context, 'Retry')),
            ),
          ],
        ),
      );
    }
    return _hasQuery
        ? _buildSearchResults()
        : Center(
            child: Text(tr(context, 'Search players, teams and matches'),
                key: ValueKey('search-prompt')));
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
          tr(context, _tabs[index]),
          style: Body1_b.style.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }

  Widget _buildSelectedResults() {
    final players = _results.players;
    final teams = _results.teams;
    final events = _results.fixtures;

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
          tr(context, 'NO RESULTS'),
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

  Widget _buildPlayerCard(PlayerCandidate player) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => openPlayerPage(context, '${player.id}'),
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
              child: ClipOval(
                child: ColoredBox(
                  color: AppColors.of(context).subtleBackground,
                  child: PlayerRemoteImage(player.image, size: 64),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    playerNameLabel(context, player.id, player.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Heading4.style.copyWith(color: colors.onSurface),
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
        widget.preferences.followedTeamIds.value.contains(team.teamId);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _teamPageEligibility.supports(team.teamId)
          ? () => openTeamPage(context, team.teamId)
          : null,
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
                    teamNameLabel(context, team.teamId, team.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Heading4.style.copyWith(color: colors.onSurface),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    teamCompetitionLabel(context,
                        widget.competitionContextResolver.resolve(team.teamId)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body1.style.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: isFollowing
                  ? tr(context, 'Unfollow team')
                  : tr(context, 'Follow team'),
              onPressed: () => _toggleTeam(team.teamId),
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

  Widget _buildEventCard(Fixture fixture) {
    final home = Team(
        teamId: fixture.homeTeamId,
        name: fixture.homeTeamName ?? '—',
        shortName: fixture.homeTeamShortName,
        imagePath: fixture.homeTeamLogo);
    final away = Team(
        teamId: fixture.awayTeamId,
        name: fixture.awayTeamName ?? '—',
        shortName: fixture.awayTeamShortName,
        imagePath: fixture.awayTeamLogo);
    final colors = Theme.of(context).colorScheme;
    final kickoff = fixture.kickoff?.toLocal();
    final date = kickoff == null
        ? tr(context, 'Date TBD')
        : DateFormat('EEE, MMM d').format(kickoff);
    final time = kickoff == null
        ? tr(context, 'Time TBD')
        : DateFormat('h:mm a').format(kickoff);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push(
        '/match/${fixture.fixtureId}?status=${fixture.status.name}',
        extra: fixture,
      ),
      child: Container(
        key: ValueKey('search-event-${fixture.fixtureId}'),
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            Expanded(child: _buildEventTeam(home)),
            _buildScore(fixture.homeScore),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Body1.style.copyWith(color: colors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Body1.style.copyWith(color: colors.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            _buildScore(fixture.awayScore),
            Expanded(child: _buildEventTeam(away)),
          ],
        ),
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
          team.shortCode ?? teamNameLabel(context, team.teamId, team.name),
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

  Widget _buildScore(int? score) {
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
        score?.toString() ?? '-',
        style: Heading4.style.copyWith(color: colors.onSurface),
      ),
    );
  }
}
