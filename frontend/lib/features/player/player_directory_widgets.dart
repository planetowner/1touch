import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/models/player_detail.dart';

class PlayerFavorites extends StatefulWidget {
  const PlayerFavorites({
    super.key,
    required this.controller,
    required this.searchRepository,
  });

  final PlayerFollowingController controller;
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
      builder: (_) => _FavoritesEditor(
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
          const SnackBar(content: Text('Could not save favorites')),
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
                const Expanded(
                  child: Text(
                    'FAVORITE PLAYERS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Body2_b.style,
                  ),
                ),
                IconButton(
                  tooltip: 'Edit favorites',
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
                child: const Text('Could not load favorites · Retry'),
              )
            else if (controller.players.isEmpty)
              TextButton(
                onPressed: _edit,
                child: const Text('Add favorite players'),
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
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  child: Container(
                                    key: const ValueKey(
                                      'favorite-player-number-badge',
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
                                      '##',
                                      style: Body2_b.style.copyWith(
                                        color: colors.onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              player.name,
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

class _FavoritesEditor extends StatefulWidget {
  const _FavoritesEditor({required this.players, required this.repository});

  final List<FollowingPlayer> players;
  final PlayerDetailRepository? repository;

  @override
  State<_FavoritesEditor> createState() => _FavoritesEditorState();
}

class _FavoritesEditorState extends State<_FavoritesEditor> {
  late final _players = [...widget.players];

  Future<void> _add() async {
    final player = await showModalBottomSheet<PlayerCandidate>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PlayerPickerSheet(repository: widget.repository),
    );
    if (player != null &&
        mounted &&
        !_players.any((item) => item.playerId == player.id)) {
      setState(
        () => _players.add(
          FollowingPlayer(
            playerId: player.id,
            name: player.name,
            imagePath: player.image,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              ListTile(
                title: const Text('FAVORITE PLAYERS'),
                leading: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                trailing: TextButton(
                  onPressed: () => Navigator.pop(context, _players),
                  child: const Text('Save'),
                ),
              ),
              TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add player'),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  itemCount: _players.length,
                  onReorderItem: (oldIndex, newIndex) => setState(() {
                    _players.insert(newIndex, _players.removeAt(oldIndex));
                  }),
                  itemBuilder: (_, index) {
                    final player = _players[index];
                    return ListTile(
                      key: ValueKey(player.playerId),
                      leading: PlayerRemoteImage(player.imagePath),
                      title: Text(player.name),
                      trailing: Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: IconButton(
                          tooltip: 'Remove player',
                          onPressed: () =>
                              setState(() => _players.removeAt(index)),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
}

class PlayerRankingPanel extends StatefulWidget {
  const PlayerRankingPanel({
    super.key,
    required this.repository,
    this.followingController,
    this.league,
    this.position,
    this.full = false,
  });

  final PlayerDirectoryRepository repository;
  final PlayerFollowingController? followingController;
  final int? league;
  final String? position;
  final bool full;

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
    var league = _league;
    var position = _position;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: league ?? 0,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'League'),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('All leagues'),
                    ),
                    for (final item in _page?.leagues ?? <PlayerLeague>[])
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name),
                      ),
                  ],
                  onChanged: (value) =>
                      update(() => league = value == 0 ? null : value),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: position ?? 'ALL',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Position'),
                  items: [
                    for (final item in ['ALL', 'GK', 'DF', 'MF', 'FW'])
                      DropdownMenuItem(
                        value: item,
                        child: Text(
                          item == 'ALL' ? 'All positions' : item,
                        ),
                      ),
                  ],
                  onChanged: (value) => update(
                    () => position = value == 'ALL' ? null : value,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      _league = league;
      _position = position;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final leagueLabel = _league == null
        ? 'ALL LEAGUES'
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
            const Text('1TOUCH RANKING', style: Body2_b.style),
            const SizedBox(width: 4),
            Icon(Icons.help_outline, size: 18, color: colors.onSurface),
            const Spacer(),
            IconButton(
              tooltip: 'Ranking filters',
              onPressed: _loading ? null : _filters,
              icon: Icon(Icons.tune, color: colors.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _DirectoryFilterPill(
                label: leagueLabel,
                onTap: _loading ? null : _filters,
              ),
              const SizedBox(width: 12),
              _DirectoryFilterPill(
                label: (_page?.season ?? 'ALL SEASONS').toUpperCase(),
                onTap: _loading ? null : _filters,
              ),
              const SizedBox(width: 12),
              _DirectoryFilterPill(
                label: (_position ?? 'ALL POSITIONS').toUpperCase(),
                onTap: _loading ? null : _filters,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_failed)
          TextButton(
            onPressed: () => _load(more: _items.isNotEmpty),
            child: const Text('Could not load ranking · Retry'),
          ),
        if (!_loading && !_failed && _items.isEmpty)
          const Text('No ranking data for these filters'),
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
              for (final player in widget.full ? _items : _items.take(5))
                _RankingRow(
                  player: player,
                  isFollowing:
                      widget.followingController?.contains(player.id) ?? false,
                ),
              const SizedBox(height: 8),
              if (!widget.full)
                GestureDetector(
                  onTap: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SafeArea(
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height * .85,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: PlayerRankingPanel(
                            repository: widget.repository,
                            followingController: widget.followingController,
                            league: _league,
                            position: _position,
                            full: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: Text('See all', style: Body2.style),
                ),
              if (widget.full && _items.length < (_page?.total ?? 0))
                TextButton(
                  onPressed: () => _load(more: true),
                  child: const Text('Load more'),
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

class _DirectoryFilterPill extends StatelessWidget {
  const _DirectoryFilterPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.of(context).subtleBackground,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Body2_b.style),
                const SizedBox(width: 6),
                const Icon(Icons.keyboard_arrow_down, size: 20),
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
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Heading5.style,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${player.position ?? '—'} • ${player.appearances} MP',
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
            const Text('ONES TO WATCH', style: Body2_b.style),
            const SizedBox(width: 8),
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
                child: const Text('Could not load players · Retry'),
              );
            }
            final players = snapshot.requireData;
            if (players.isEmpty) {
              return const Text(
                'No players with 10 rated appearances and an improved average',
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
    final changePrefix = player.change >= 0 ? '+' : '';
    return Semantics(
      button: true,
      label: 'Open ${player.name}',
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
                                  '$changePrefix${player.change.toStringAsFixed(2)}',
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
                        player.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Body1_b.style.copyWith(color: colors.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rating ${player.recent.toStringAsFixed(2)}',
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
