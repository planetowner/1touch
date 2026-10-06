import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/cache/cache_policy.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/season_label.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class PlayerDetailStore extends ChangeNotifier {
  PlayerDetailStore(
      {required this.playerId, this.repository, PlayerDetail? initial}) {
    if (initial != null) {
      _visible[null] = initial;
      _requests[null] = Future.value(initial);
    }
  }
  final int? playerId;
  final PlayerDetailRepository? repository;
  // 같은 화면의 네 탭이 같은 시즌 조회를 공유해요. 화면을 나가면 함께 해제돼요.
  final _requests = <int?, Future<PlayerDetail>>{};
  final _visible = <int?, PlayerDetail>{};
  final _refreshing = <int?>{};

  PlayerDetail? snapshot(int? seasonId) =>
      _visible[seasonId] ??
      switch (repository ?? playerDetailRepository) {
        CachedPlayerDetailRepository cached when playerId != null =>
          cached.snapshotFor(playerId!, seasonId: seasonId)?.data,
        _ => null,
      };

  Future<PlayerDetail> load(int? seasonId) =>
      _requests.putIfAbsent(seasonId, () => _load(seasonId));

  Future<PlayerDetail> _load(int? seasonId) async {
    final source = repository ?? playerDetailRepository;
    if (source is CachedPlayerDetailRepository) {
      final memory = source.snapshotFor(playerId!, seasonId: seasonId);
      if (memory != null) {
        _visible[seasonId] = memory.data;
        _refreshIfStale(source, seasonId, memory.savedAt);
        return memory.data;
      }
      final restored = await source.restoreFor(playerId!, seasonId: seasonId);
      if (restored != null) {
        _visible[seasonId] = restored.data;
        notifyListeners();
        _refreshIfStale(source, seasonId, restored.savedAt);
        return restored.data;
      }
    }
    final fresh = await source.load(playerId!, seasonId: seasonId);
    _visible[seasonId] = fresh;
    notifyListeners();
    return fresh;
  }

  void _refreshIfStale(
      CachedPlayerDetailRepository source, int? seasonId, DateTime savedAt) {
    if (!AppCachePolicy.shouldRefresh(
          tier: CacheTier.standard,
          trigger: CacheSyncTrigger.screenEnter,
          savedAt: savedAt,
        ) ||
        !_refreshing.add(seasonId)) {
      return;
    }
    unawaited(source.load(playerId!, seasonId: seasonId).then((fresh) {
      _visible[seasonId] = fresh;
      _requests[seasonId] = Future.value(fresh);
      notifyListeners();
    }).catchError((Object _) {
      // Keep the restored detail visible while offline.
    }).whenComplete(() => _refreshing.remove(seasonId)));
  }

  void invalidate(int? seasonId) {
    _requests.remove(seasonId);
    _visible.remove(seasonId);
    notifyListeners();
  }
}

class PlayerDetailScope extends InheritedNotifier<PlayerDetailStore> {
  const PlayerDetailScope(
      {super.key, required PlayerDetailStore store, required super.child})
      : super(notifier: store);
  PlayerDetailStore get store => notifier!;
  static PlayerDetailStore? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerDetailScope>()?.notifier;
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
        // A snapshot is always keyed to this exact player and season.
        final detail = snapshot.connectionState == ConnectionState.done
            ? snapshot.data ?? store.snapshot(widget.seasonId)
            : store.snapshot(widget.seasonId);
        if (detail == null && !snapshot.hasError) {
          return const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: FootballLoadingIndicator()));
        }
        if (detail == null && snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tr(context, 'Could not load player data')),
            TextButton(
                onPressed: () =>
                    setState(() => store.invalidate(widget.seasonId)),
                child: Text(tr(context, 'Retry'))),
          ]));
        }
        return widget.builder(context, detail!);
      },
    );
  }
}

class PlayerSeasonSelector extends StatelessWidget {
  const PlayerSeasonSelector(
      {super.key, required this.detail, required this.onChanged, this.width});
  final PlayerDetail detail;
  final ValueChanged<int?> onChanged;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final foreground = Theme.of(context).colorScheme.onSurface;
    return AppDropdown<int>(
      value: detail.selectedSeason?.id,
      width: width,
      triggerHeight: 48,
      matchMenuWidth: width != null,
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
                  '${compactSeasonLabel(season.name)} · ${competitionNameLabel(context, season.competitionId, season.competitionName)}',
            ),
          )
          .toList(),
      onChanged: (seasonId) => onChanged(seasonId),
    );
  }
}
