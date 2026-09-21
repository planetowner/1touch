import 'package:flutter/material.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/models/player_detail.dart';

class PlayerDetailStore {
  PlayerDetailStore(
      {required this.playerId, this.repository, PlayerDetail? initial}) {
    if (initial != null) _requests[null] = Future.value(initial);
  }
  final int? playerId;
  final PlayerDetailRepository? repository;
  // 같은 화면의 네 탭이 같은 시즌 조회를 공유해요. 화면을 나가면 함께 해제돼요.
  final _requests = <int?, Future<PlayerDetail>>{};
  Future<PlayerDetail> load(int? seasonId) => _requests.putIfAbsent(
      seasonId,
      () => Future.sync(() => (repository ?? playerDetailRepository)
          .load(playerId!, seasonId: seasonId)));
  void invalidate(int? seasonId) {
    _requests.remove(seasonId);
  }
}

class PlayerDetailScope extends InheritedWidget {
  const PlayerDetailScope(
      {super.key, required this.store, required super.child});
  final PlayerDetailStore store;
  static PlayerDetailStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerDetailScope>()?.store;
  @override
  bool updateShouldNotify(PlayerDetailScope oldWidget) =>
      oldWidget.store != store;
}

class PlayerDetailView extends StatefulWidget {
  const PlayerDetailView(
      {super.key,
      required this.playerId,
      required this.builder,
      this.seasonId});
  final int? playerId, seasonId;
  final Widget Function(BuildContext, PlayerDetail) builder;
  @override
  State<PlayerDetailView> createState() => _PlayerDetailViewState();
}

class _PlayerDetailViewState extends State<PlayerDetailView> {
  PlayerDetailStore? _local;
  @override
  Widget build(BuildContext context) {
    if (widget.playerId == null) {
      return const Center(child: Text('Player data unavailable'));
    }
    final shared = PlayerDetailScope.maybeOf(context);
    if (_local?.playerId != widget.playerId) {
      _local = PlayerDetailStore(playerId: widget.playerId);
    }
    final store = shared?.playerId == widget.playerId ? shared! : _local!;
    return FutureBuilder<PlayerDetail>(
      future: store.load(widget.seasonId),
      builder: (context, snapshot) {
        // 새 시즌을 불러오는 동안 이전 시즌의 값을 새 제목 아래 표시하지 않아요.
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load player data'),
            TextButton(
                onPressed: () =>
                    setState(() => store.invalidate(widget.seasonId)),
                child: const Text('Retry')),
          ]));
        }
        return widget.builder(context, snapshot.requireData);
      },
    );
  }
}

class PlayerSeasonSelector extends StatelessWidget {
  const PlayerSeasonSelector(
      {super.key, required this.detail, required this.onChanged});
  final PlayerDetail detail;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
        initialValue: detail.selectedSeason?.id,
        isExpanded: true,
        decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 16)),
        hint: const Text('Select a season'),
        items: detail.seasons
            .map((season) => DropdownMenuItem(
                value: season.id,
                child: Text('${season.name} · ${season.competitionName}',
                    maxLines: 1, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: onChanged,
      );
}
