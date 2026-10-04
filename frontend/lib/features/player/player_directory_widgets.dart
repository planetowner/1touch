import 'package:flutter/material.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/app_info_button.dart';
import 'package:onetouch/core/player_navigation.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_watch_name.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_directory_sheets.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PlayerFavorites extends StatefulWidget {
  const PlayerFavorites({
    super.key,
    required this.controller,
    required this.searchRepository,
    this.title = 'FAVORITE PLAYERS',
  });

  final PlayerFollowingController controller;
  final String title;
  final PlayerDetailRepository? searchRepository;

  @override
  State<PlayerFavorites> createState() => _PlayerFavoritesState();
}

class _PlayerFavoritesState extends State<PlayerFavorites> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.loaded) widget.controller.load();
  }

  Future<void> _edit() async {
    final players = await showModalBottomSheet<List<FollowingPlayer>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FollowingPlayersEditorSheet(
        players: widget.controller.players,
        repository: widget.searchRepository,
      ),
    );
    if (players == null) return;
    try {
      await widget.controller.save(players.map((player) => player.playerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'Could not save favorites'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (_, __) {
        final controller = widget.controller;
        return Column(
          key: const ValueKey('players-favorites-section'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    trUpper(context, widget.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style,
                  ),
                ),
                IconButton(
                  tooltip: tr(context, 'Edit favorites'),
                  onPressed:
                      controller.loading || !controller.loaded ? null : _edit,
                  icon: Icon(
                    Icons.border_color,
                    size: 24,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.error != null && controller.loaded)
              TextButton(
                onPressed: controller.loading ? null : controller.load,
                child: Text(tr(context, 'Could not load favorites · Retry')),
              ),
            if (controller.loading && !controller.loaded)
              const SizedBox(
                height: 112,
                child: Center(child: FootballLoadingIndicator()),
              )
            else if (controller.error != null && !controller.loaded)
              TextButton(
                onPressed: controller.load,
                child: Text(tr(context, 'Could not load favorites · Retry')),
              )
            else if (controller.players.isEmpty)
              DottedBorder(
                color: colors.onSurface.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashPattern: const [6, 6],
                borderType: BorderType.RRect,
                radius: const Radius.circular(8),
                child: Material(
                  color: isDark
                      ? const Color(0xFF272828)
                      : AppColors.of(context).cardBackground,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    key: const ValueKey('players-empty-favorites'),
                    onTap: _edit,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 32, color: colors.onSurface),
                            const SizedBox(height: 8),
                            Text(
                              tr(context,
                                  "You aren't following any players yet.\nAdd some now."),
                              textAlign: TextAlign.center,
                              style: Body1.style.copyWith(
                                color: colors.onSurface,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: controller.players.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                  itemBuilder: (_, index) {
                    final player = controller.players[index];
                    return InkWell(
                      key: ValueKey('favorite-player-${player.playerId}'),
                      onTap: () => openPlayerPage(
                        context,
                        player.playerId.toString(),
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 79,
                        height: 129,
                        child: Stack(
                          children: [
                            Positioned(
                              left: 5,
                              top: 5,
                              child: ClipOval(
                                child: SizedBox(
                                  key: ValueKey(
                                    'favorite-player-circle-${player.playerId}',
                                  ),
                                  width: 74,
                                  height: 74,
                                  child: ColoredBox(
                                    color:
                                        AppColors.of(context).subtleBackground,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: PlayerRemoteImage(
                                        player.imagePath,
                                        size: 64,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              left: 5,
                              top: 87,
                              child: SizedBox(
                                width: 74,
                                child: Text(
                                  playerNameLabel(
                                    context,
                                    player.playerId,
                                    player.name,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Body1.style,
                                ),
                              ),
                            ),
                            if (player.jerseyNumber case final number?)
                              Positioned(
                                left: 0,
                                top: 0,
                                child: Container(
                                  key: ValueKey(
                                    'favorite-player-number-${player.playerId}',
                                  ),
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppPalette.lightGrey
                                        : AppPalette.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$number',
                                    maxLines: 1,
                                    style: Body2_b.style,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class PlayerRankingPanel extends StatefulWidget {
  const PlayerRankingPanel({
    super.key,
    required this.repository,
    this.followingController,
    this.detailRepository,
    this.league,
    this.position,
  });

  final PlayerDirectoryRepository repository;
  final PlayerFollowingController? followingController;
  final PlayerDetailRepository? detailRepository;
  final int? league;
  final String? position;

  @override
  State<PlayerRankingPanel> createState() => PlayerRankingPanelState();
}

class PlayerRankingPanelState extends State<PlayerRankingPanel> {
  late int? _league = widget.league;
  late String? _position = widget.position;
  PlayerRankingPage? _page;
  List<PlayerRank> _items = [];
  bool _loading = true;
  bool _failed = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    widget.repository.cachedRankings.addListener(_handleCachedRanking);
    _applyCachedRanking();
    _load();
  }

  @override
  void didUpdateWidget(PlayerRankingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.repository, oldWidget.repository)) {
      oldWidget.repository.cachedRankings.removeListener(_handleCachedRanking);
      widget.repository.cachedRankings.addListener(_handleCachedRanking);
    }
    if (!identical(widget.repository, oldWidget.repository) ||
        widget.league != oldWidget.league ||
        widget.position != oldWidget.position) {
      _league = widget.league;
      _position = widget.position;
      _load();
    }
  }

  @override
  void dispose() {
    widget.repository.cachedRankings.removeListener(_handleCachedRanking);
    super.dispose();
  }

  void _handleCachedRanking() {
    final cached =
        widget.repository.cachedRanking(league: _league, position: _position);
    if (cached == null || identical(cached, _page)) return;
    setState(() => _showPage(cached));
  }

  void _applyCachedRanking() {
    final cached =
        widget.repository.cachedRanking(league: _league, position: _position);
    if (cached != null) _showPage(cached);
  }

  void _showPage(PlayerRankingPage page) {
    _page = page;
    _items = page.items;
    _loading = false;
    _failed = false;
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final requestId = ++_requestId;
    final league = _league;
    final position = _position;
    final cached = forceRefresh
        ? _page
        : widget.repository.cachedRanking(league: league, position: position);
    setState(() {
      if (!forceRefresh) {
        _page = cached;
        _items = cached?.items ?? [];
      }
      _loading = cached == null || forceRefresh;
      _failed = false;
    });
    try {
      final page = await (forceRefresh
          ? widget.repository.refreshRanking(league: league, position: position)
          : widget.repository.ranking(league: league, position: position));
      if (!mounted || requestId != _requestId) return;
      final latest =
          widget.repository.cachedRanking(league: league, position: position);
      setState(() => _showPage(latest ?? page));
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted && requestId == _requestId) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> refresh() => _load(forceRefresh: true);

  Future<void> _filters() async {
    final selection = await showModalBottomSheet<PlayerRankingFilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerRankingFilterSheet(
        leagues: _page?.leagues ?? const [],
        season: _page?.season,
        initialLeague: _league,
        initialPosition: _position,
      ),
    );
    if (selection != null && mounted) {
      _league = selection.league;
      _position = selection.position;
      await _load();
    }
  }

  Future<void> _clearLeague() async {
    if (_loading || _league == null) return;
    setState(() => _league = null);
    await _load();
  }

  Future<void> _clearPosition() async {
    if (_loading || _position == null) return;
    setState(() => _position = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leagueLabel = _league == null
        ? trUpper(context, 'All leagues')
        : _page?.leagues
                .where((item) => item.id == _league)
                .firstOrNull
                ?.name
                .toUpperCase() ??
            'LEAGUE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('players-ranking-title-row'),
          children: [
            Text(trUpper(context, '1touch Ranking'), style: Body2_b.style),
            const SizedBox(width: 4),
            const AppInfoButton(
              key: ValueKey('players-ranking-info'),
              message:
                  "Evaluates and ranks players using 1touch's own data-driven performance metrics.",
              layoutSize: 18,
            ),
            const Spacer(),
            IconButton(
              tooltip: tr(context, 'Ranking filters'),
              onPressed: _loading ? null : _filters,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(
                width: 24,
                height: 24,
              ),
              icon: Icon(Icons.tune, color: colors.onSurface),
            ),
          ],
        ),
        if (_league != null || _position != null) ...[
          const SizedBox(height: 16),
          SingleChildScrollView(
            key: const ValueKey('active-ranking-filters'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (_league != null)
                  _ActiveDirectoryFilterChip(
                    key: const ValueKey('active-ranking-league-filter'),
                    label: competitionNameLabel(context, _league, leagueLabel),
                    onRemove: _loading ? null : _clearLeague,
                  ),
                if (_league != null && _position != null)
                  const SizedBox(width: 12),
                if (_position != null)
                  _ActiveDirectoryFilterChip(
                    key: const ValueKey('active-ranking-position-filter'),
                    label: _positionLabel(context, _position!),
                    onRemove: _loading ? null : _clearPosition,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_failed)
          TextButton(
            onPressed: () => _load(forceRefresh: _items.isNotEmpty),
            child: Text(tr(context, 'Could not load ranking · Retry')),
          ),
        if (!_loading && !_failed && _items.isEmpty)
          Text(tr(context, 'No ranking data for these filters')),
        if (_items.isNotEmpty) _rankingCard(context),
        if (_loading && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: FootballLoadingIndicator()),
          ),
      ],
    );
  }

  Widget _rankingCard(BuildContext context) {
    Widget buildCard() => Container(
          key: const ValueKey('players-ranking-card'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.of(context).cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: [
              for (var index = 0;
                  index < _items.length && index < 5;
                  index++) ...[
                if (index > 0) const SizedBox(height: 16),
                _RankingRow(
                  player: _items[index],
                  isFollowing:
                      widget.followingController?.contains(_items[index].id) ??
                          false,
                ),
              ],
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PlayerFullRankingSheet(
                    players: _items,
                    followingController: widget.followingController,
                    detailRepository: widget.detailRepository,
                  ),
                ),
                child: Text(
                  tr(context, 'See all'),
                  style: Body2.style.copyWith(height: 1.3),
                ),
              ),
            ],
          ),
        );

    final controller = widget.followingController;
    return controller == null
        ? buildCard()
        : ListenableBuilder(
            listenable: controller,
            builder: (_, __) => buildCard(),
          );
  }
}

String _positionLabel(BuildContext context, String position) => trUpper(
      context,
      switch (position) {
        'GK' => 'Goalkeeper',
        'DF' => 'Defender',
        'MF' => 'Midfielder',
        'FW' => 'Forward',
        _ => position.toUpperCase(),
      },
    );

class _ActiveDirectoryFilterChip extends StatelessWidget {
  const _ActiveDirectoryFilterChip({
    super.key,
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
        child: InkWell(
          onTap: onRemove,
          borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
          child: Padding(
            padding: AppDropdownTokens.triggerPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Body2_b.style),
                const SizedBox(width: 4),
                const Icon(Icons.close, size: AppDropdownTokens.iconSize),
              ],
            ),
          ),
        ),
      );
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.player, required this.isFollowing});

  final PlayerRank player;
  final bool isFollowing;

  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey('ranking-player-${player.id}'),
        onTap: () => context.push('/players/${player.id}'),
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text('${player.rank}', style: Heading4.style),
              ),
              ClipOval(
                child: ColoredBox(
                  color: AppColors.of(context).subtleBackground,
                  child: PlayerRemoteImage(player.image, size: 56),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerNameLabel(context, player.id, player.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Heading5.style.copyWith(height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, '{position} • {count} MP', {
                        'position': player.position ?? '—',
                        'count': player.appearances
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Body2.style.copyWith(height: 1.3),
                    ),
                  ],
                ),
              ),
              if (isFollowing) ...[
                Icon(
                  Icons.star,
                  size: 24,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
              ],
              Text(player.score.toStringAsFixed(1),
                  style: Heading5.style.copyWith(height: 1.1)),
            ],
          ),
        ),
      );
}

class PlayersToWatch extends StatefulWidget {
  const PlayersToWatch({
    super.key,
    required this.repository,
  });

  final PlayerDirectoryRepository repository;

  @override
  State<PlayersToWatch> createState() => PlayersToWatchState();
}

class PlayersToWatchState extends State<PlayersToWatch> {
  late Future<List<PlayerWatch>> _request =
      Future.sync(widget.repository.watch);

  CachedPlayerWatchRepository? get _cachedRepository =>
      widget.repository is CachedPlayerWatchRepository
          ? widget.repository as CachedPlayerWatchRepository
          : null;

  @override
  void initState() {
    super.initState();
    _cachedRepository?.cachedWatch.addListener(_handleCachedWatch);
  }

  @override
  void didUpdateWidget(PlayersToWatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository)) return;
    if (oldWidget.repository is CachedPlayerWatchRepository) {
      (oldWidget.repository as CachedPlayerWatchRepository)
          .cachedWatch
          .removeListener(_handleCachedWatch);
    }
    _cachedRepository?.cachedWatch.addListener(_handleCachedWatch);
    _request = Future.sync(widget.repository.watch);
  }

  @override
  void dispose() {
    _cachedRepository?.cachedWatch.removeListener(_handleCachedWatch);
    super.dispose();
  }

  void _handleCachedWatch() {
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    final repository = _cachedRepository;
    final request = Future.sync(
        repository == null ? widget.repository.watch : repository.refreshWatch);
    setState(() {
      _request = request;
    });
    try {
      await request;
    } on Object {
      // 요청이 실패하면 FutureBuilder에서 다시 시도 버튼을 보여줘요.
    }
  }

  Widget _watchResult(List<PlayerWatch> players) {
    if (players.isEmpty) {
      return Text(
        tr(context,
            'No players with 10 rated appearances and an improved average'),
      );
    }
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, index) => _WatchCard(player: players[index]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr(context, 'ONES TO WATCH'), style: Body2_b.style),
            const SizedBox(width: 4),
            const AppInfoButton(
              key: ValueKey('players-ones-to-watch-info'),
              message:
                  'Highlights players with the highest performance growth over the recent 5 matches, based on 1touch metrics.',
              layoutSize: 16,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_cachedRepository?.cachedWatch.value case final players?)
          _watchResult(players)
        else
          FutureBuilder<List<PlayerWatch>>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: FootballLoadingIndicator()),
                );
              }
              if (snapshot.hasError) {
                return TextButton(
                  onPressed: () => setState(
                    () => _request = Future.sync(widget.repository.watch),
                  ),
                  child: Text(tr(context, 'Could not load players · Retry')),
                );
              }
              return _watchResult(snapshot.requireData);
            },
          ),
      ],
    );
  }
}

class _WatchCard extends StatelessWidget {
  const _WatchCard({required this.player});

  final PlayerWatch player;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: tr(context, 'Open {name}',
          {'name': playerNameLabel(context, player.id, player.name)}),
      child: InkWell(
        key: ValueKey('ones-to-watch-player-${player.id}'),
        onTap: () => context.push('/players/${player.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          key: const ValueKey('ones-to-watch-card'),
          width: 150,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: appWatchCardShadows(context),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final portraitSize = constraints.maxHeight - 10;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              key:
                                  const ValueKey('ones-to-watch-image-surface'),
                              color: isDark
                                  ? AppPalette.darkGrey
                                  : appColors.subtleBackground,
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 0,
                            width: portraitSize,
                            height: portraitSize,
                            child: SizedBox(
                              key: ValueKey(
                                  'ones-to-watch-portrait-${player.id}'),
                              child: PlayerRemoteImage(
                                player.image,
                                size: portraitSize,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 10,
                            child: player.jerseyNumber == null
                                ? const SizedBox.shrink()
                                : Text(
                                    '${player.jerseyNumber}',
                                    key: ValueKey(
                                        'ones-to-watch-jersey-${player.id}'),
                                    style: Heading2.style,
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                Container(
                  key: const ValueKey('ones-to-watch-info-surface'),
                  width: double.infinity,
                  height: 88,
                  color: isDark ? AppPalette.lightGrey : AppPalette.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PlayerWatchName(
                          name:
                              playerNameLabel(context, player.id, player.name),
                          style:
                              Body1_b.style.copyWith(color: colors.onSurface),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        switch (player.teamName?.trim()) {
                          null || '' => '',
                          final name =>
                            teamNameLabel(context, player.teamId, name),
                        },
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Eyebrow.style.copyWith(color: colors.onSurface),
                      ),
                    ],
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
