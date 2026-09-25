part of 'match_info_features.dart';

// One row of the match-events list: a player plus every minute they're
// credited for this event type, e.g. a brace shows as "23',67'" on one row
// rather than two separate rows.
class _GroupedMatchEvent {
  final int? playerId;
  final String player;
  final String team; // 'home' | 'away'
  final String type; // 'goal' | 'redCard'
  final List<String> minutes;
  _GroupedMatchEvent(
      {this.playerId,
      required this.player,
      required this.team,
      required this.type})
      : minutes = [];
}

List<_GroupedMatchEvent> _groupMatchEvents(List<Map<String, dynamic>> events) {
  final rows = <_GroupedMatchEvent>[];
  for (final e in events) {
    final team = e['team'] as String;
    final player = e['player'] as String;
    final playerId = e['playerId'] as int?;
    final type = (e['type'] as String?) ?? 'goal';
    final existing = rows
        .where((r) =>
            r.team == team &&
            r.playerId == playerId &&
            r.player == player &&
            r.type == type)
        .firstOrNull;
    final row = existing ??
        _GroupedMatchEvent(
            playerId: playerId, player: player, team: team, type: type);
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
      size: 20,
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
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (goalRows.isNotEmpty) _buildSection(goalRows, 'goal'),
          if (goalRows.isNotEmpty && redCardRows.isNotEmpty)
            const SizedBox(height: 8),
          if (redCardRows.isNotEmpty) _buildSection(redCardRows, 'redCard'),
        ],
      ),
    );
  }

  // Each team owns an independent chronological column. An event from one
  // team therefore never inserts an empty row into the other team's list.
  Widget _buildSection(List<_GroupedMatchEvent> rows, String type) {
    final homeRows = rows.where((row) => row.team == 'home').toList();
    final awayRows = rows.where((row) => row.team == 'away').toList();

    Widget eventColumn(List<_GroupedMatchEvent> teamRows, String team) =>
        Column(
          key: ValueKey('match-events-$team-$type'),
          children: [
            for (var index = 0; index < teamRows.length; index++) ...[
              if (index > 0) const SizedBox(height: 8),
              _EventRowContent(
                key: ValueKey(
                    'match-event-$team-$type-${teamRows[index].player}'),
                row: teamRows[index],
                alignRight: team == 'away',
              ),
            ],
          ],
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: eventColumn(homeRows, 'home'),
        ),
        // 선수명 끝과 중앙 아이콘의 레이어 경계를 14.5px 떨어뜨려요.
        const SizedBox(width: 14.5),
        SizedBox(
          key: ValueKey('match-events-icon-$type'),
          width: 20,
          child: Center(child: _eventTypeIcon(type)),
        ),
        const SizedBox(width: 14.5),
        Expanded(
          child: eventColumn(awayRows, 'away'),
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
    final style = DefaultTextStyle.of(context)
        .style
        .merge(Body1.style.copyWith(height: 1.3));
    final name =
        playerNameLabel(context, row.playerId, row.player, short: true);
    final minutes = [
      for (var index = 0; index < row.minutes.length; index++)
        '${row.minutes[index]}${index < row.minutes.length - 1 ? ',' : ''}',
    ];

    double textWidth(String value) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final widestMinute = minutes.map(textWidth).reduce((a, b) => a > b ? a : b);
    final nameWidth = textWidth(name);
    final spaceWidth = textWidth(' ');

    return LayoutBuilder(
      builder: (context, constraints) {
        // 이름은 실제 글자 폭을 쓰되, 좁은 화면에서도 시간 하나는 온전히 보여줘요.
        final maxNameWidth = (constraints.maxWidth - 8 - widestMinute)
            .clamp(0.0, constraints.maxWidth);
        final nameText = SizedBox(
          width: nameWidth.clamp(0.0, maxNameWidth),
          child: Text(name,
              style: style,
              maxLines: 1,
              softWrap: false,
              textAlign: alignRight ? TextAlign.left : TextAlign.right,
              overflow: TextOverflow.ellipsis),
        );
        final minuteText = Expanded(
          child: Wrap(
            alignment: alignRight ? WrapAlignment.end : WrapAlignment.start,
            spacing: spaceWidth,
            // 추가시간을 포함한 시각 하나를 쪼개지 않고 다음 줄로 넘겨요.
            children: [
              for (final minute in minutes)
                Text(minute, style: style, maxLines: 1, softWrap: false),
            ],
          ),
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: alignRight
              ? [nameText, const SizedBox(width: 8), minuteText]
              : [minuteText, const SizedBox(width: 8), nameText],
        );
      },
    );
  }
}
