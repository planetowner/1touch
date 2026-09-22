import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/models/following_player.dart';
import 'package:onetouch/models/player_detail.dart';

typedef PlayerRankingFilterSelection = ({int? league, String? position});

class PlayerRankingFilterSheet extends StatefulWidget {
  const PlayerRankingFilterSheet(
      {super.key,
      required this.leagues,
      required this.season,
      required this.initialLeague,
      required this.initialPosition});
  final List<PlayerLeague> leagues;
  final String? season;
  final int? initialLeague;
  final String? initialPosition;
  @override
  State<PlayerRankingFilterSheet> createState() =>
      _PlayerRankingFilterSheetState();
}

class _PlayerRankingFilterSheetState extends State<PlayerRankingFilterSheet> {
  late int? _league = widget.initialLeague;
  late String? _position = widget.initialPosition;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider = isDark ? AppPalette.lightGrey : appColors.divider;
    final positions = <(String?, String)>[
      (null, 'All positions'),
      ('GK', 'Goalkeeper'),
      ('DF', 'Defender'),
      ('MF', 'Midfielder'),
      ('FW', 'Forward'),
    ];
    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .92,
      builder: (context, controller) => Material(
        key: const ValueKey('players-ranking-filter-sheet'),
        color: isDark ? AppPalette.darkGrey : AppPalette.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            children: [
              _SheetTitle(
                  title: 'Filter', onClose: () => Navigator.pop(context)),
              const SizedBox(height: 48),
              const Text('LEAGUE', style: Body2_b.style),
              const SizedBox(height: 16),
              _FilterChoice(
                  label: 'All leagues',
                  selected: _league == null,
                  divider: divider,
                  onTap: () => setState(() => _league = null)),
              for (final league in widget.leagues)
                _FilterChoice(
                    label: league.name,
                    selected: _league == league.id,
                    divider: divider,
                    onTap: () => setState(() => _league = league.id)),
              const SizedBox(height: 48),
              const Text('SEASON', style: Body2_b.style),
              const SizedBox(height: 16),
              _FixedSeasonRow(
                  season: widget.season ?? 'Current season', divider: divider),
              const SizedBox(height: 48),
              const Text('POSITION', style: Body2_b.style),
              const SizedBox(height: 16),
              for (final position in positions)
                _FilterChoice(
                    label: position.$2,
                    selected: _position == position.$1,
                    divider: divider,
                    onTap: () => setState(() => _position = position.$1)),
            ],
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: ElevatedButton(
              key: const ValueKey('players-ranking-update-filter'),
              onPressed: () => Navigator.pop<PlayerRankingFilterSelection>(
                  context, (league: _league, position: _position)),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.onSurface,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text('UPDATE FILTER',
                  style: Body2_b.style.copyWith(color: colors.onPrimary)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice(
      {required this.label,
      required this.selected,
      required this.divider,
      required this.onTap});
  final String label;
  final bool selected;
  final Color divider;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: Body1.style),
          trailing: selected
              ? Icon(Icons.check,
                  color: Theme.of(context).colorScheme.onSurface)
              : null,
          onTap: onTap,
        ),
        Divider(color: divider, height: 1),
      ]);
}

class _FixedSeasonRow extends StatelessWidget {
  const _FixedSeasonRow({required this.season, required this.divider});
  final String season;
  final Color divider;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Text(season, style: Body1.style),
            const Spacer(),
            Icon(Icons.check, color: Theme.of(context).colorScheme.onSurface),
          ]),
        ),
        Divider(color: divider, height: 1),
      ]);
}

class FollowingPlayersEditorSheet extends StatefulWidget {
  const FollowingPlayersEditorSheet(
      {super.key, required this.players, this.repository});
  final List<FollowingPlayer> players;
  final PlayerDetailRepository? repository;
  @override
  State<FollowingPlayersEditorSheet> createState() =>
      _FollowingPlayersEditorSheetState();
}

class _FollowingPlayersEditorSheetState
    extends State<FollowingPlayersEditorSheet> {
  final _search = TextEditingController();
  late final List<FollowingPlayer> _players = [...widget.players];
  final Map<int, Future<PlayerDetail?>> _details = {};
  List<PlayerCandidate> _results = [];
  PlayerCandidate? _selected;
  bool _searching = false;
  bool _changed = false;
  int _request = 0;
  PlayerDetailRepository get _repository =>
      widget.repository ?? playerDetailRepository;

  @override
  void initState() {
    super.initState();
    for (final player in _players) {
      _details[player.playerId] = _loadDetail(player.playerId);
    }
    _search.addListener(_onSearch);
  }

  Future<PlayerDetail?> _loadDetail(int id) async {
    try {
      return await _repository.load(id);
    } on Object {
      return null;
    }
  }

  Future<void> _onSearch() async {
    final query = _search.text.trim();
    final request = ++_request;
    if (query.isEmpty) {
      setState(() {
        _searching = false;
        _results = [];
        _selected = null;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final candidates = await _repository.search(query);
      if (!mounted || request != _request) return;
      setState(() => _results = candidates
          .where((candidate) => !_contains(candidate.id))
          .take(20)
          .toList());
    } on Object {
      if (mounted && request == _request) setState(() => _results = []);
    }
  }

  bool _contains(int id) => _players.any((player) => player.playerId == id);

  void _save() {
    final selected = _selected;
    if (selected != null && !_contains(selected.id)) {
      _players.add(FollowingPlayer(
          playerId: selected.id,
          name: selected.name,
          imagePath: selected.image));
    }
    Navigator.pop(context, _players);
  }

  @override
  void dispose() {
    _request++;
    _search
      ..removeListener(_onSearch)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final divider = isDark ? AppPalette.lightGrey : appColors.divider;
    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .92,
      builder: (context, controller) => Material(
        key: const ValueKey('following-players-sheet'),
        color: isDark ? AppPalette.darkGrey : AppPalette.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(children: [
            _SheetTitle(
                title: 'Following Players',
                onClose: () => Navigator.pop(context)),
            const SizedBox(height: 12),
            Container(
              key: const ValueKey('following-players-search'),
              decoration: BoxDecoration(
                color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _search,
                style: Body1.style.copyWith(color: colors.onSurface),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: 'Search players to add!',
                  hintStyle:
                      Body1.style.copyWith(color: appColors.mutedForeground),
                  border: InputBorder.none,
                  suffixIcon: _searching
                      ? IconButton(
                          onPressed: _search.clear,
                          icon: Icon(Icons.close, color: colors.onSurface))
                      : Icon(Icons.search, color: colors.onSurface),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
                child: _searching
                    ? _searchResults(controller, divider)
                    : _followedPlayers(controller, divider)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const ValueKey('following-players-update'),
                  onPressed: _changed || _selected != null ? _save : null,
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                        const EdgeInsets.symmetric(vertical: 18)),
                    shape: WidgetStateProperty.all(RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
                    backgroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.disabled)
                            ? (isDark
                                ? Colors.grey.shade700
                                : const Color(0xFFC8C8C8))
                            : colors.onSurface),
                    foregroundColor: WidgetStateProperty.resolveWith((states) =>
                        states.contains(WidgetState.disabled)
                            ? Colors.grey.shade400
                            : colors.onPrimary),
                  ),
                  child: const Text('UPDATE',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _followedPlayers(ScrollController controller, Color divider) =>
      ReorderableListView.builder(
        scrollController: controller,
        buildDefaultDragHandles: false,
        itemCount: _players.length,
        onReorderItem: (oldIndex, newIndex) {
          setState(() {
            _players.insert(newIndex, _players.removeAt(oldIndex));
            _changed = true;
          });
        },
        itemBuilder: (context, index) {
          final player = _players[index];
          return _FollowingPlayerRow(
            key: ValueKey('following-editor-${player.playerId}'),
            player: player,
            detail: _details[player.playerId],
            primary: index == 0,
            divider: divider,
            dragHandle: ReorderableDragStartListener(
              index: index,
              child: Icon(Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurface, size: 28),
            ),
            onRemove: () => setState(() {
              _players.removeAt(index);
              _changed = true;
            }),
          );
        },
      );

  Widget _searchResults(ScrollController controller, Color divider) =>
      ListView.builder(
        controller: controller,
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final player = _results[index];
          final selected = _selected?.id == player.id;
          return _SearchPlayerRow(
            player: player,
            divider: divider,
            selected: selected,
            onSelect: () => setState(() => _selected = player),
          );
        },
      );
}

class _FollowingPlayerRow extends StatelessWidget {
  const _FollowingPlayerRow(
      {super.key,
      required this.player,
      required this.detail,
      required this.primary,
      required this.divider,
      required this.dragHandle,
      required this.onRemove});
  final FollowingPlayer player;
  final Future<PlayerDetail?>? detail;
  final bool primary;
  final Color divider;
  final Widget dragHandle;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => FutureBuilder<PlayerDetail?>(
        future: detail,
        builder: (_, snapshot) {
          final value = snapshot.data;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                IconButton(
                  tooltip: 'Remove player',
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle,
                      color: Color(0xFFFF5C5C), size: 20),
                ),
                ClipOval(
                    child: ColoredBox(
                  color: AppColors.of(context).subtleBackground,
                  child: PlayerRemoteImage(
                      value?.profile.image ?? player.imagePath,
                      size: 52),
                )),
                const SizedBox(width: 16),
                Expanded(
                    child: _PlayerIdentity(
                  name: value?.profile.name ?? player.name,
                  team: value?.profile.teamName,
                  number: value?.profile.jerseyNumber,
                  primary: primary,
                )),
                dragHandle,
              ]),
            ),
            Divider(color: divider, height: 1),
          ]);
        },
      );
}

class _SearchPlayerRow extends StatelessWidget {
  const _SearchPlayerRow(
      {required this.player,
      required this.divider,
      required this.selected,
      required this.onSelect});
  final PlayerCandidate player;
  final Color divider;
  final bool selected;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context) => Column(children: [
        InkWell(
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              ClipOval(
                  child: ColoredBox(
                color: AppColors.of(context).subtleBackground,
                child: PlayerRemoteImage(player.image, size: 56),
              )),
              const SizedBox(width: 16),
              Expanded(child: _PlayerIdentity(name: player.name)),
              IconButton(
                onPressed: onSelect,
                icon: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 28),
              ),
            ]),
          ),
        ),
        Divider(color: divider, height: 1),
      ]);
}

class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity(
      {required this.name, this.team, this.number, this.primary = false});
  final String name;
  final String? team;
  final int? number;
  final bool primary;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Heading5.style)),
            if (primary)
              const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.star_border, size: 18)),
          ]),
          if (team != null) ...[
            const SizedBox(height: 2),
            Text(number == null ? team! : '$team #$number',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Body2.style),
          ],
        ],
      );
}

class PlayerFullRankingSheet extends StatefulWidget {
  const PlayerFullRankingSheet({
    super.key,
    required this.players,
    required this.followingController,
    this.detailRepository,
  });
  final List<PlayerRank> players;
  final PlayerFollowingController? followingController;
  final PlayerDetailRepository? detailRepository;
  @override
  State<PlayerFullRankingSheet> createState() => _PlayerFullRankingSheetState();
}

class _PlayerFullRankingSheetState extends State<PlayerFullRankingSheet> {
  final _search = TextEditingController();
  final Map<int, Future<PlayerDetail?>> _details = {};
  PlayerDetailRepository get _repository =>
      widget.detailRepository ?? playerDetailRepository;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _search
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final players = query.isEmpty
        ? widget.players
        : widget.players
            .where((player) => player.name.toLowerCase().contains(query))
            .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    return DraggableScrollableSheet(
      initialChildSize: .92,
      minChildSize: .55,
      maxChildSize: .92,
      builder: (context, controller) => Material(
        key: const ValueKey('full-ranking-sheet'),
        color: isDark ? AppPalette.darkGrey : AppPalette.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(children: [
            _SheetTitle(
                title: '1Touch Ranking', onClose: () => Navigator.pop(context)),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppPalette.lightGrey : AppPalette.lightGreyBox,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _search,
                style: Body1.style.copyWith(color: colors.onSurface),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  hintText: 'Look for players',
                  hintStyle:
                      Body1.style.copyWith(color: appColors.mutedForeground),
                  border: InputBorder.none,
                  suffixIcon: Icon(Icons.search, color: colors.onSurface),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: players.length,
                itemBuilder: (_, index) {
                  final player = players[index];
                  final detail = _details.putIfAbsent(player.id, () async {
                    try {
                      return await _repository.load(player.id);
                    } on Object {
                      return null;
                    }
                  });
                  return _FullRankingRow(
                    player: player,
                    detail: detail,
                    following:
                        widget.followingController?.contains(player.id) ??
                            false,
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FullRankingRow extends StatelessWidget {
  const _FullRankingRow(
      {required this.player, required this.detail, required this.following});
  final PlayerRank player;
  final Future<PlayerDetail?> detail;
  final bool following;
  @override
  Widget build(BuildContext context) => InkWell(
        key: ValueKey('full-ranking-player-${player.id}'),
        onTap: () => context.push('/players/${player.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(
                width: 48,
                child: Text('${player.rank}', style: Heading4.style)),
            ClipOval(
                child: ColoredBox(
              color: AppColors.of(context).subtleBackground,
              child: PlayerRemoteImage(player.image, size: 56),
            )),
            const SizedBox(width: 16),
            Expanded(
                child: FutureBuilder<PlayerDetail?>(
              future: detail,
              builder: (_, snapshot) {
                final profile = snapshot.data?.profile;
                return _PlayerIdentity(
                    name: player.name,
                    team: profile?.teamName,
                    number: profile?.jerseyNumber);
              },
            )),
            if (following) const Icon(Icons.star, size: 24),
            const SizedBox(width: 8),
            Text(player.score.toStringAsFixed(1), style: Heading5.style),
          ]),
        ),
      );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title, required this.onClose});
  final String title;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Center(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Heading5.style)),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close,
                  color: Theme.of(context).colorScheme.onSurface, size: 28),
            ),
          ),
        ],
      );
}
