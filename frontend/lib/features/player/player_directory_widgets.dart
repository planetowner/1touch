import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
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
                    widget.title,
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
            if (controller.loading)
              const SizedBox(
                height: 112,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.error != null)
              TextButton(
                onPressed: controller.load,
                child: Text(tr(context, 'Could not load favorites · Retry')),
              )
            else if (controller.players.isEmpty)
              TextButton(
                onPressed: _edit,
                child: Text(tr(context, 'Add favorite players')),
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
                      onTap: () => context.push('/players/${player.playerId}'),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 78,
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                ClipOval(
                                  child: ColoredBox(
                                    color:
                                        AppColors.of(context).subtleBackground,
                                    child: PlayerRemoteImage(
                                      player.imagePath,
                                      size: 74,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              playerNameLabel(
                                  context, player.playerId, player.name),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Body1.style,
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
  State<PlayerRankingPanel> createState() => _PlayerRankingPanelState();
}

class _PlayerRankingPanelState extends State<PlayerRankingPanel> {
  late int? _league = widget.league;
  late String? _position = widget.position;
  PlayerRankingPage? _page;
  List<PlayerRank> _items = [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
      if (!more) _items = [];
    });
    try {
      final page = await widget.repository.ranking(
        league: _league,
        position: _position,
        offset: more ? _items.length : 0,
      );
      if (!mounted) return;
      setState(() {
        _page = page;
        _items = [..._items, ...page.items];
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

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
        ? tr(context, 'ALL LEAGUES')
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
          children: [
            Text(tr(context, '1TOUCH RANKING'), style: Body2_b.style),
            const SizedBox(width: 4),
            Icon(Icons.help_outline, size: 18, color: colors.onSurface),
            const Spacer(),
            IconButton(
              tooltip: tr(context, 'Ranking filters'),
              onPressed: _loading ? null : _filters,
              icon: Icon(Icons.tune, color: colors.onSurface),
            ),
          ],
        ),
        if (_league != null || _position != null) ...[
          const SizedBox(height: 16),
          SingleChildScrollView(
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
                    label: _positionLabel(_position!),
                    onRemove: _loading ? null : _clearPosition,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (_failed)
          TextButton(
            onPressed: () => _load(more: _items.isNotEmpty),
            child: Text(tr(context, 'Could not load ranking · Retry')),
          ),
        if (!_loading && !_failed && _items.isEmpty)
          Text(tr(context, 'No ranking data for these filters')),
        if (_items.isNotEmpty) _rankingCard(context),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _rankingCard(BuildContext context) {
    Widget buildCard() => Container(
          key: const ValueKey('players-ranking-card'),
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.of(context).cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: [
              for (final player in _items.take(5))
                _RankingRow(
                  player: player,
                  isFollowing:
                      widget.followingController?.contains(player.id) ?? false,
                ),
              const SizedBox(height: 8),
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
                child: Text(tr(context, 'See all'), style: Body2.style),
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

String _positionLabel(String position) => switch (position) {
      'GK' => 'GOALKEEPER',
      'DF' => 'DEFENDER',
      'MF' => 'MIDFIELDER',
      'FW' => 'FORWARD',
      _ => position.toUpperCase(),
    };

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
                Text(tr(context, label), style: Body2_b.style),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 28,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playerNameLabel(context, player.id, player.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Heading5.style,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, '{position} • {count} MP', {
                        'position': player.position ?? '—',
                        'count': player.appearances
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Body2.style,
                    ),
                  ],
                ),
              ),
              if (isFollowing) ...[
                Icon(
                  Icons.star,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
              ],
              Text(player.score.toStringAsFixed(1), style: Heading5.style),
            ],
          ),
        ),
      );
}

class PlayersToWatch extends StatefulWidget {
  const PlayersToWatch({super.key, required this.repository});

  final PlayerDirectoryRepository repository;

  @override
  State<PlayersToWatch> createState() => _PlayersToWatchState();
}

class _PlayersToWatchState extends State<PlayersToWatch> {
  late Future<List<PlayerWatch>> _request =
      Future.sync(widget.repository.watch);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr(context, 'ONES TO WATCH'), style: Body2_b.style),
            const SizedBox(width: 4),
            Icon(Icons.help_outline, size: 16, color: colors.onSurface),
          ],
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<PlayerWatch>>(
          future: _request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
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
            final players = snapshot.requireData;
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
                itemCount: players.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, index) => _WatchCard(player: players[index]),
              ),
            );
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
    final changeColor =
        player.change >= 0 ? const Color(0xFF31C979) : const Color(0xFFFF5C5C);
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
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          key: const ValueKey('ones-to-watch-image-surface'),
                          color: isDark
                              ? AppPalette.darkGrey
                              : appColors.subtleBackground,
                        ),
                      ),
                      Positioned(
                        right: -4,
                        bottom: 0,
                        child: PlayerRemoteImage(player.image, size: 116),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('##', style: Heading2.style),
                            Row(
                              children: [
                                Icon(
                                  player.change >= 0
                                      ? Icons.arrow_drop_up
                                      : Icons.arrow_drop_down,
                                  color: changeColor,
                                  size: 22,
                                ),
                                Text(
                                  player.change.abs().toStringAsFixed(2),
                                  style: Body2_b.style.copyWith(
                                    color: changeColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: const ValueKey('ones-to-watch-info-surface'),
                  width: double.infinity,
                  color: isDark ? AppPalette.lightGrey : AppPalette.white,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerNameLabel(context, player.id, player.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Body1_b.style.copyWith(color: colors.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(context, 'Rating {rating}',
                            {'rating': player.recent.toStringAsFixed(2)}),
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
