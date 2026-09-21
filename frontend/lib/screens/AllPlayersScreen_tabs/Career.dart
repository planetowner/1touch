import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/player_detail.dart';

class CareerTab extends StatefulWidget {
  const CareerTab({super.key, this.player, this.playerId});
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  @override
  State<CareerTab> createState() => _CareerTabState();
}

class _CareerTabState extends State<CareerTab> {
  int? _competition;
  final Set<String> _collapsed = {};
  final Set<String> _expanded = {};
  @override
  void didUpdateWidget(covariant CareerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _competition = null;
      _collapsed.clear();
      _expanded.clear();
    }
  }

  @override
  Widget build(BuildContext context) => PlayerDetailView(
      playerId: widget.id,
      builder: (context, detail) => SingleChildScrollView(
          key: const ValueKey('player-career-scroll'),
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 144),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PlayerSection(
                title: 'TROPHIES',
                trailing: Text('TEAM', style: Body2_b.style),
                child: _trophies(detail.honours)),
            const SizedBox(height: 48),
            _history(detail.career),
          ])));

  Widget _trophies(List<PlayerHonour> honours) {
    final teams = <int, List<PlayerHonour>>{};
    for (final item in honours) {
      teams.putIfAbsent(item.teamId, () => []).add(item);
    }
    return PlayerSurface(
        key: const ValueKey('player-career-trophies-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (teams.isEmpty) const Text('Team trophy records unavailable'),
          for (final entry in teams.entries) ...[
            if (entry.key != teams.keys.first) const Divider(height: 36),
            Row(children: [
              PlayerRemoteImage(entry.value.first.teamImage),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(entry.value.first.teamName ?? 'Team unavailable',
                      style: Body2_b.style)),
              Text('${entry.value.length}', style: Body2_b.style)
            ]),
            const SizedBox(height: 16),
            for (final competition
                in entry.value.map((h) => h.competitionId).toSet()) ...[
              Row(children: [
                const Icon(Icons.emoji_events_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        entry.value
                                .firstWhere(
                                    (h) => h.competitionId == competition)
                                .competitionName ??
                            'Competition unavailable',
                        style: Heading5.style))
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h
                    in entry.value.where((h) => h.competitionId == competition))
                  Chip(label: Text(h.season ?? '—')),
              ]),
              const SizedBox(height: 16),
            ],
          ],
        ]));
  }

  Widget _history(List<PlayerCareerRecord> history) {
    final competitions = <int, String>{};
    for (final season in history) {
      for (final c in season.competitions) {
        competitions[c.id] = c.name;
      }
    }
    final visible = history
        .where((s) =>
            _competition == null ||
            s.competitions.any((c) => c.id == _competition))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('HISTORY', style: Body2_b.style),
      const SizedBox(height: 12),
      DropdownButtonFormField<int>(
          key: const Key('career-competition-filter'),
          initialValue: _competition ?? 0,
          isExpanded: true,
          decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12)),
          items: [
            const DropdownMenuItem(value: 0, child: Text('ALL LEAGUES')),
            for (final entry in competitions.entries)
              DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value,
                      maxLines: 1, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (value) =>
              setState(() => _competition = value == 0 ? null : value)),
      const SizedBox(height: 16),
      PlayerSurface(
          key: const ValueKey('player-career-history-card'),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            const PlayerRecordRow(
                label: Text('Season / Team'), record: null, header: true),
            if (visible.isEmpty) const Text('No history available'),
            for (var index = 0; index < visible.length; index++)
              _season(visible[index], index == 0),
          ])),
    ]);
  }

  Widget _season(PlayerCareerRecord season, bool newest) {
    final key = '${season.season}-${season.teamId}';
    final canExpand = _competition == null;
    final isExpanded = canExpand &&
        (_expanded.contains(key) || (newest && !_collapsed.contains(key)));
    final competitions = season.competitions
        .where((c) => _competition == null || c.id == _competition)
        .toList();
    final record =
        _competition == null ? season.record : competitions.first.record;
    return Column(children: [
      InkWell(
          key: Key('career-season-$key'),
          onTap: canExpand
              ? () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(key);
                      _collapsed.add(key);
                    } else {
                      _collapsed.remove(key);
                      _expanded.add(key);
                    }
                  })
              : null,
          child: PlayerRecordRow(
              record: record,
              label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(season.season, style: Body2.style),
                    const SizedBox(height: 4),
                    Row(children: [
                      PlayerRemoteImage(season.teamImage, size: 20),
                      const SizedBox(width: 4),
                      Flexible(
                          child: Text(season.teamCode ?? season.teamName,
                              style: Body2_b.style,
                              overflow: TextOverflow.ellipsis)),
                      if (canExpand)
                        Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 18)
                    ]),
                  ]))),
      if (isExpanded)
        for (final c in competitions)
          PlayerRecordRow(
              key: Key('career-competition-$key-${c.id}'),
              label: Text(c.name, style: Body2.style),
              record: c.record),
      Divider(color: AppColors.of(context).divider, height: 1),
    ]);
  }
}
