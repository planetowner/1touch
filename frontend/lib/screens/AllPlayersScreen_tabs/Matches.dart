import 'package:flutter/material.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab({super.key, this.player, this.playerId});
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  int? _seasonId;
  @override
  void didUpdateWidget(covariant MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _seasonId = null;
    }
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: widget.id,
      seasonId: _seasonId,
      builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-matches-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
          child: Column(children: [
            PlayerSeasonSelector(
                key: ValueKey(
                    'player-matches-season-${detail.selectedSeason?.id}'),
                detail: detail,
                onChanged: (id) => setState(() => _seasonId = id)),
            const SizedBox(height: 24),
            if (detail.matches.any((m) => m.live)) ...[
              PlayerSection(
                  title: tr(context, 'LIVE'),
                  child: Column(children: [
                    for (final match in detail.matches.where((m) => m.live))
                      PlayerDetailMatchCard(match: match)
                  ])),
              const SizedBox(height: 24),
            ],
            PlayerSection(
                title: tr(context, 'RECENT MATCHES'),
                child: Column(children: [
                  if (detail.matches.isEmpty)
                    Text(tr(context, 'No appearances this season')),
                  for (final match in detail.matches.where((m) => !m.live))
                    PlayerDetailMatchCard(match: match),
                ])),
          ])));
}
