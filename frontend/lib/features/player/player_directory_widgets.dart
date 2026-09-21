import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/models/following_player.dart';

class PlayerFavorites extends StatefulWidget {
  const PlayerFavorites(
      {super.key, required this.controller, required this.searchRepository});
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
            repository: widget.searchRepository));
    if (players == null) return;
    try {
      await widget.controller.save(players.map((p) => p.playerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save favorites')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.controller,
      builder: (_, __) {
        final controller = widget.controller;
        return PlayerSection(
            title: 'FAVORITES',
            trailing: IconButton(
                tooltip: 'Edit favorites',
                onPressed:
                    controller.loading || !controller.loaded ? null : _edit,
                icon: const Icon(Icons.edit_outlined)),
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.error != null
                    ? TextButton(
                        onPressed: controller.load,
                        child: const Text('Could not load favorites · Retry'))
                    : controller.players.isEmpty
                        ? TextButton(
                            onPressed: _edit,
                            child: const Text('Add favorite players'))
                        : SizedBox(
                            height: 112,
                            child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: controller.players.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (_, i) {
                                  final player = controller.players[i];
                                  return InkWell(
                                      onTap: () => context
                                          .push('/players/${player.playerId}'),
                                      child: SizedBox(
                                          width: 82,
                                          child: Column(children: [
                                            PlayerRemoteImage(player.imagePath,
                                                size: 60),
                                            const SizedBox(height: 8),
                                            Text(player.name,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center)
                                          ])));
                                })));
      });
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
        builder: (_) => PlayerPickerSheet(repository: widget.repository));
    if (player != null &&
        mounted &&
        !_players.any((p) => p.playerId == player.id)) {
      setState(() => _players.add(FollowingPlayer(
          playerId: player.id, name: player.name, imagePath: player.image)));
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(children: [
            ListTile(
                title: const Text('FAVORITE PLAYERS'),
                leading: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
                trailing: TextButton(
                    onPressed: () => Navigator.pop(context, _players),
                    child: const Text('Save'))),
            TextButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('Add player')),
            Expanded(
                child: ReorderableListView.builder(
                    itemCount: _players.length,
                    onReorderItem: (oldIndex, newIndex) => setState(() {
                          _players.insert(
                              newIndex, _players.removeAt(oldIndex));
                        }),
                    itemBuilder: (_, i) {
                      final player = _players[i];
                      return ListTile(
                          key: ValueKey(player.playerId),
                          leading: PlayerRemoteImage(player.imagePath),
                          title: Text(player.name),
                          trailing: Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: IconButton(
                                  tooltip: 'Remove player',
                                  onPressed: () =>
                                      setState(() => _players.removeAt(i)),
                                  icon: const Icon(
                                      Icons.remove_circle_outline))));
                    }))
          ])));
}

class PlayerRankingPanel extends StatefulWidget {
  const PlayerRankingPanel(
      {super.key,
      required this.repository,
      this.league,
      this.position,
      this.full = false});
  final PlayerDirectoryRepository repository;
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
  bool _loading = true, _failed = false;
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
          offset: more ? _items.length : 0);
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
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          initialValue: league ?? 0,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'League'),
                          items: [
                            const DropdownMenuItem(
                                value: 0, child: Text('All leagues')),
                            for (final l in _page?.leagues ?? <PlayerLeague>[])
                              DropdownMenuItem(value: l.id, child: Text(l.name))
                          ],
                          onChanged: (v) =>
                              update(() => league = v == 0 ? null : v)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                          initialValue: position ?? 'ALL',
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Position'),
                          items: [
                            for (final p in ['ALL', 'GK', 'DF', 'MF', 'FW'])
                              DropdownMenuItem(
                                  value: p,
                                  child: Text(p == 'ALL' ? 'All positions' : p))
                          ],
                          onChanged: (v) =>
                              update(() => position = v == 'ALL' ? null : v)),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Apply')),
                    ])))));
    if (applied == true && mounted) {
      _league = league;
      _position = position;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final leagueLabel = _league == null
        ? 'All leagues'
        : _page?.leagues.where((l) => l.id == _league).firstOrNull?.name ??
            'League';
    final missing = _page?.leagues
        .where((l) => l.available == 0 && (_league == null || l.id == _league))
        .map((l) => l.name)
        .join(', ');
    return PlayerSection(
        title: '1TOUCH RANKING',
        trailing: IconButton(
            tooltip: 'Ranking filters',
            onPressed: _loading ? null : _filters,
            icon: const Icon(Icons.tune)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, children: [
            ActionChip(
                label: Text(leagueLabel),
                onPressed: _loading ? null : _filters),
            ActionChip(
                label: Text(_position ?? 'All positions'),
                onPressed: _loading ? null : _filters)
          ]),
          const SizedBox(height: 8),
          Text(
              'Current season${_page?.season == null ? '' : ' · ${_page!.season}'}',
              style: Body2.style),
          const SizedBox(height: 12),
          if (missing != null && missing.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Ranking data unavailable: $missing')),
          if (_failed)
            TextButton(
                onPressed: () => _load(more: _items.isNotEmpty),
                child: const Text('Could not load ranking · Retry')),
          if (!_loading && !_failed && _items.isEmpty)
            const Text('No ranking data for these filters'),
          if (_items.isNotEmpty)
            PlayerSurface(
                child: Column(children: [
              for (final player in widget.full ? _items : _items.take(5))
                _RankingRow(player: player)
            ])),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
          if (!_loading && _items.isNotEmpty && !widget.full)
            Center(
                child: TextButton(
                    onPressed: () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => SafeArea(
                            child: SizedBox(
                                height: MediaQuery.sizeOf(context).height * .85,
                                child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(24),
                                    child: PlayerRankingPanel(
                                        repository: widget.repository,
                                        league: _league,
                                        position: _position,
                                        full: true))))),
                    child: const Text('See all'))),
          if (!_loading && widget.full && _items.length < (_page?.total ?? 0))
            Center(
                child: TextButton(
                    onPressed: () => _load(more: true),
                    child: const Text('Load more'))),
        ]));
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow({required this.player});
  final PlayerRank player;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => context.push('/players/${player.id}'),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            SizedBox(
                width: 32, child: Text('${player.rank}', style: Body2_b.style)),
            PlayerRemoteImage(player.image, size: 42),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Body2_b.style),
                  Text('${player.position ?? '—'} · ${player.appearances} MP',
                      style: Body2.style)
                ])),
            const SizedBox(width: 8),
            Text(player.score.toStringAsFixed(1), style: Heading4.style)
          ])));
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
  Widget build(BuildContext context) => PlayerSection(
      title: 'ONES TO WATCH',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Average rating · Last 5 vs previous 5 matches'),
        const SizedBox(height: 12),
        FutureBuilder<List<PlayerWatch>>(
            future: _request,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return TextButton(
                    onPressed: () => setState(
                        () => _request = Future.sync(widget.repository.watch)),
                    child: const Text('Could not load players · Retry'));
              }
              final players = snapshot.requireData;
              if (players.isEmpty) {
                return const Text(
                    'No players with 10 rated appearances and an improved average');
              }
              return SizedBox(
                  height: 215,
                  child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final player = players[i];
                        return InkWell(
                            onTap: () => context.push('/players/${player.id}'),
                            child: SizedBox(
                                width: 170,
                                child: PlayerSurface(
                                    child: Column(children: [
                                  PlayerRemoteImage(player.image, size: 64),
                                  const SizedBox(height: 8),
                                  Text(player.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Body2_b.style),
                                  const SizedBox(height: 8),
                                  Text('+${player.change.toStringAsFixed(2)}',
                                      style: Heading3.style),
                                  Text(
                                      '${player.previous.toStringAsFixed(2)} → ${player.recent.toStringAsFixed(2)}'),
                                ]))));
                      }));
            }),
      ]));
}
