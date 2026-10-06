import 'package:flutter/material.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/features/match_info/live_match_motion.dart';

class MatchesTab extends StatefulWidget {
  const MatchesTab(
      {super.key, this.player, this.playerId, this.scrollResetToken = 0});
  final Player? player;
  final int? playerId;
  final int scrollResetToken;
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
    if (oldWidget.scrollResetToken != widget.scrollResetToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = PrimaryScrollController.maybeOf(context);
        if (controller != null && controller.hasClients) {
          controller.jumpTo(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: widget.id,
      seasonId: _seasonId,
      builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-matches-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PlayerSeasonSelector(
                  key: ValueKey(
                      'player-matches-season-${detail.selectedSeason?.id}'),
                  detail: detail,
                  onChanged: (id) => setState(() => _seasonId = id)),
            ),
            const SizedBox(height: 32),
            if (detail.matches.any((m) => m.live)) ...[
              PlayerSection(
                  title: trUpper(context, 'Live'),
                  titleAccessory: const LivePulseDot(),
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
