import 'package:flutter/material.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/features/player/player_detail_widgets.dart';
import 'package:onetouch/features/player/player_stat_value.dart';
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlayerSection(
                title: 'TROPHIES',
                child: _trophies(detail.honours),
              ),
              // TODO: Restore the TEAM / PERSONAL trophy filter when personal
              // trophy data is added to the API.
              const SizedBox(height: 48),
              _history(detail.career),
            ],
          ),
        ),
      );

  Widget _trophies(List<PlayerHonour> honours) {
    final teams = <int, List<PlayerHonour>>{};
    for (final honour in honours) {
      teams.putIfAbsent(honour.teamId, () => []).add(honour);
    }
    return PlayerSurface(
      key: const ValueKey('player-career-trophies-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (teams.isEmpty) const Text('Team trophy records unavailable'),
          for (var teamIndex = 0;
              teamIndex < teams.entries.length;
              teamIndex++) ...[
            if (teamIndex > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Divider(
                  color: AppColors.of(context).divider,
                  height: 1,
                ),
              ),
            _teamHonours(teams.entries.elementAt(teamIndex).value),
          ],
        ],
      ),
    );
  }

  Widget _teamHonours(List<PlayerHonour> honours) {
    final first = honours.first;
    final competitions = honours.map((item) => item.competitionId).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            PlayerRemoteImage(first.teamImage, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                (first.teamName ?? 'Team unavailable').toUpperCase(),
                style: Body2_b.style,
              ),
            ),
            Text('${honours.length}', style: Body2_b.style),
          ],
        ),
        const SizedBox(height: 18),
        for (final competitionId in competitions) ...[
          Row(
            children: [
              const Icon(Icons.emoji_events_outlined, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  honours
                          .firstWhere(
                              (item) => item.competitionId == competitionId)
                          .competitionName ??
                      'Competition unavailable',
                  style: Heading5.style,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final honour in honours
                  .where((item) => item.competitionId == competitionId))
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    honour.season ?? '—',
                    style: Body2.style.copyWith(color: AppPalette.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  Widget _history(List<PlayerCareerRecord> history) {
    final competitions = <int, String>{};
    for (final season in history) {
      for (final competition in season.competitions) {
        competitions[competition.id] = competition.name;
      }
    }
    final visible = history
        .where((season) =>
            _competition == null ||
            season.competitions
                .any((competition) => competition.id == _competition))
        .toList();
    final label = _competition == null
        ? 'ALL LEAGUES'
        : competitions[_competition] ?? 'COMPETITION';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('HISTORY', style: Body2_b.style),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: _FilterButton(
                  key: const Key('career-competition-filter'),
                  label: label,
                  onTap: () => _showFilter(competitions),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PlayerSurface(
          key: const ValueKey('player-career-history-card'),
          child: Column(
            children: [
              _header(),
              const SizedBox(height: 8),
              if (visible.isEmpty) const Text('No history available'),
              for (var index = 0; index < visible.length; index++)
                _season(visible[index], index == 0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final style = Body2.style.copyWith(
      color: AppColors.of(context).mutedForeground,
    );
    return Row(
      children: [
        Expanded(flex: 2, child: Text('Season', style: style)),
        Expanded(flex: 3, child: Text('Team', style: style)),
        Expanded(
            flex: 2,
            child: Text('MP', textAlign: TextAlign.center, style: style)),
        Expanded(
            flex: 2,
            child: Text('WR', textAlign: TextAlign.center, style: style)),
        Expanded(
            flex: 2,
            child: Text('Rating', textAlign: TextAlign.center, style: style)),
        const SizedBox(width: 22),
      ],
    );
  }

  Widget _season(PlayerCareerRecord season, bool newest) {
    final key = '${season.season}-${season.teamId}';
    final canExpand = _competition == null;
    final isExpanded = canExpand &&
        (_expanded.contains(key) || (newest && !_collapsed.contains(key)));
    final competitions = season.competitions
        .where((item) => _competition == null || item.id == _competition)
        .toList();
    final record =
        _competition == null ? season.record : competitions.first.record;
    return Column(
      children: [
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                    flex: 2, child: Text(season.season, style: Body2_b.style)),
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      PlayerRemoteImage(season.teamImage, size: 22),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          season.teamCode ?? season.teamName,
                          overflow: TextOverflow.ellipsis,
                          style: Body2_b.style,
                        ),
                      ),
                    ],
                  ),
                ),
                _value('${record.appearances}'),
                _value(record.winRate == null
                    ? '—'
                    : '${playerNumber(record.winRate, decimals: 0)}%'),
                Expanded(
                  flex: 2,
                  child: Center(child: _rating(record.rating)),
                ),
                if (canExpand)
                  SizedBox(
                    width: 22,
                    child: Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                  )
                else
                  const SizedBox(width: 22),
              ],
            ),
          ),
        ),
        if (isExpanded)
          for (final competition in competitions)
            Padding(
              key: Key('career-competition-$key-${competition.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      competition.name,
                      overflow: TextOverflow.ellipsis,
                      style: Body2_b.style.copyWith(
                        color: AppColors.of(context).mutedForeground,
                      ),
                    ),
                  ),
                  _value('${competition.record.appearances}'),
                  _value(competition.record.winRate == null
                      ? '—'
                      : '${playerNumber(competition.record.winRate, decimals: 0)}%'),
                  Expanded(
                    flex: 2,
                    child: Center(child: _rating(competition.record.rating)),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),
        Divider(color: AppColors.of(context).divider, height: 1),
      ],
    );
  }

  Widget _value(String text) => Expanded(
        flex: 2,
        child: Text(text, textAlign: TextAlign.center, style: Body2_b.style),
      );

  Widget _rating(double? rating) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: AppPalette.black,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          rating?.toStringAsFixed(1) ?? '—',
          style: Body2_b.style.copyWith(color: AppPalette.white),
        ),
      );

  Future<void> _showFilter(Map<int, String> competitions) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              title: const Text('ALL LEAGUES'),
              trailing: _competition == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, 0),
            ),
            for (final entry in competitions.entries)
              ListTile(
                title: Text(entry.value.toUpperCase()),
                trailing:
                    _competition == entry.key ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, entry.key),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _competition = selected == 0 ? null : selected);
    }
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppPalette.lightGrey : AppPalette.white,
      borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
        onTap: onTap,
        child: Padding(
          padding: AppDropdownTokens.triggerPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Body2_b.style,
                ),
              ),
              const SizedBox(width: AppDropdownTokens.gap),
              const AppDropdownChevron(),
            ],
          ),
        ),
      ),
    );
  }
}
