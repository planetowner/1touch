import 'package:flutter/material.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/l10n/app_localizations.dart';

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
      return Center(child: Text(tr(context, 'Player data unavailable')));
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
            Text(tr(context, 'Could not load player data')),
            TextButton(
                onPressed: () =>
                    setState(() => store.invalidate(widget.seasonId)),
                child: Text(tr(context, 'Retry'))),
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return AppDropdown<int>(
      value: detail.selectedSeason?.id,
      hintText: tr(context, 'SELECT A SEASON'),
      backgroundColor: surface,
      foregroundColor: foreground,
      textStyle: Body2_b.style,
      boxShadow: appCardShadows(context),
      options: detail.seasons
          .map(
            (season) => AppDropdownOption<int>(
              value: season.id,
              label:
                  '${season.name} · ${competitionNameLabel(context, season.competitionId, season.competitionName)}',
            ),
          )
          .toList(),
      onChanged: (seasonId) => onChanged(seasonId),
    );
  }
}
