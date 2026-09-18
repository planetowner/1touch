part of 'match_info_features.dart';

// One row of the match-events list: a player plus every minute they're
// credited for this event type, e.g. a brace shows as "23',67'" on one row
// rather than two separate rows.
class _GroupedMatchEvent {
  final String player;
  final String team; // 'home' | 'away'
  final String type; // 'goal' | 'redCard'
  final List<String> minutes;
  _GroupedMatchEvent(
      {required this.player, required this.team, required this.type})
      : minutes = [];
}

List<_GroupedMatchEvent> _groupMatchEvents(List<Map<String, dynamic>> events) {
  final rows = <_GroupedMatchEvent>[];
  for (final e in events) {
    final team = e['team'] as String;
    final player = e['player'] as String;
    final type = (e['type'] as String?) ?? 'goal';
    final existing = rows
        .where((r) => r.team == team && r.player == player && r.type == type)
        .firstOrNull;
    final row =
        existing ?? _GroupedMatchEvent(player: player, team: team, type: type);
    if (existing == null) rows.add(row);
    row.minutes.add(e['minute'] as String);
  }
  return rows;
}

// A goal/red-card icon, shared by one whole section of rows rather than
// repeated per row — there's one ball icon for the goals section and one
// card icon for the red-cards section, not one per scorer.
Widget _eventTypeIcon(String type) => MatchEventIcon(
      type: type == 'redCard' ? LineupEventType.redCard : LineupEventType.goal,
    );

class MatchEventsSection extends StatelessWidget {
  final List<Map<String, dynamic>> events;

  const MatchEventsSection({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    final rows = _groupMatchEvents(events);
    final goalRows = rows.where((r) => r.type == 'goal').toList();
    final redCardRows = rows.where((r) => r.type == 'redCard').toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          if (goalRows.isNotEmpty) _buildSection(goalRows, 'goal'),
          if (redCardRows.isNotEmpty) _buildSection(redCardRows, 'redCard'),
        ],
      ),
    );
  }

  // Each team owns an independent chronological column. An event from one
  // team therefore never inserts an empty row into the other team's list.
  Widget _buildSection(List<_GroupedMatchEvent> rows, String type) {
    final homeRows = rows.where((row) => row.team == 'home');
    final awayRows = rows.where((row) => row.team == 'away');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            key: ValueKey('match-events-home-$type'),
            children: [
              for (final row in homeRows)
                _EventRowContent(
                  key: ValueKey('match-event-home-$type-${row.player}'),
                  row: row,
                  alignRight: false,
                ),
            ],
          ),
        ),
        SizedBox(
          width: 20,
          child: Center(child: _eventTypeIcon(type)),
        ),
        Expanded(
          child: Column(
            key: ValueKey('match-events-away-$type'),
            children: [
              for (final row in awayRows)
                _EventRowContent(
                  key: ValueKey('match-event-away-$type-${row.player}'),
                  row: row,
                  alignRight: true,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventRowContent extends StatelessWidget {
  final _GroupedMatchEvent row;
  final bool alignRight;
  const _EventRowContent({
    super.key,
    required this.row,
    required this.alignRight,
  });

  @override
  Widget build(BuildContext context) {
    final minuteText = Flexible(
      flex: 2,
      child: Text(
        row.minutes.join(','),
        style: Eyebrow.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final nameText = Flexible(
      flex: 3,
      child: Text(row.player,
          style: Eyebrow.style, overflow: TextOverflow.ellipsis),
    );

    // Minute always flares to the outer edge, name leans toward the shared
    // center icon — mirrored between the home (left) and away (right) side.
    final children = alignRight
        ? [nameText, const SizedBox(width: 6), minuteText]
        : [minuteText, const SizedBox(width: 6), nameText];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: children,
      ),
    );
  }
}
