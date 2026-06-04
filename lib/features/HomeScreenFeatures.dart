import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../data/teamdata.dart';
import '../models/fixture.dart';
import '../models/league.dart';
import '../models/mock_data.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/stylesheet_dark.dart";

// 1. Converted _showSyncDialog to a reusable Widget class
class SyncDialog extends StatelessWidget {
  const SyncDialog({super.key});

  // Static helper to show the dialog easily from anywhere
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) => const SyncDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2C2C2C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Sync with your calendar?", style: Heading5.style),
            const SizedBox(height: 16),
            Text(
              "We’ll add your favorite team’s upcoming matches straight to your calendar, so you never miss a kickoff. You’ll get notified before each game — no spam, no surprises.",
              style: Body1.style,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text("YES, SYNC IT!",
                    style: Body2_b.style.copyWith(color: Colors.black)),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text("CANCEL", style: Body2_b.style),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 2. Converted _showTeamSelection to a reusable StatefulWidget class
class TeamSelectionSheet extends StatefulWidget {
  const TeamSelectionSheet({super.key});

  // Static helper to show the sheet easily from anywhere
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => const TeamSelectionSheet(),
    );
  }

  @override
  State<TeamSelectionSheet> createState() => _TeamSelectionSheetState();
}

class _TeamSelectionSheetState extends State<TeamSelectionSheet> {
  // Debug code
  // @override
  // void initState() {
  //   super.initState();
  //   for (final id in followingTeamIds(1001)) {
  //     final fixtures = fixturesByTeam(id);
  //     print('teamId: $id, fixtures count: ${fixtures.length}, leagueName: ${leagueNames[fixtures.firstOrNull?.leagueId]}');
  //   }
  // }

  // Data moved inside the State class
  final List<Map<String, dynamic>> _followingTeams = followingTeamIds(1001).map((id) {
    final t = mockTeamById(id);
    final leagueId = fixturesByTeam(id).firstOrNull?.leagueId;
    final position = leagueId != null ? standingByTeam(leagueId, id)?.position : null;
    final leagueName = leagueId != null ? (leagueNames[leagueId] ?? '') : '';
    return <String, dynamic>{
      'name': t.name,
      'league': position != null ? '$leagueName ${ordinal(position)}' : leagueName,
      'logo': t.imagePath ?? '',
      'isSelected': id == mockUserProfiles.firstWhere((p) => p.userId == 1001).favoriteTeamId,
    };
  }).toList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 24), // Spacing for centering
              Text("Following Teams", style: Heading5.style),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _followingTeams.length,
              itemBuilder: (context, index) {
                final team = _followingTeams[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      team['logo'],
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>Image.asset(
                        'TeamLogos/Barcelona.png',
                        height: 24,
                        width: 24,
                      ),
                    ),
                  ),
                  title: Text(
                    team['name'],
                    style: Body1_b.style,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(team['league'] ?? '', style: Body2.style),
                  trailing: team['isSelected']
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                  onTap: () {
                    // Handle team selection here
                    setState(() {
                      for (var t in _followingTeams) {
                        t['isSelected'] = false;
                      }
                      team['isSelected'] = true;
                    });
                    // You would also update the main 'realteam' data here
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Logic to switch to the selected team
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text("SWITCH",
                  style: Body2_b.style.copyWith(color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}

class MyTeams extends StatelessWidget {
  final List<Team> teams;

  const MyTeams({super.key, required this.teams});

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return SizedBox.shrink();
    final team = teams[0];
    final match = team.nextMatch;
    final leagueId = match?.leagueId ?? team.lastMatch?.leagueId;
    final leagueName = leagueNames[leagueId] ?? '';
    final rank = leagueId != null
        ? standingByTeam(leagueId, team.id)?.position
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Material(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 375,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF272828),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // TEAM HEADER
              GestureDetector(
                onTap: () {
                  context.push(
                      '/team/${team.id}'); // Or use ID if your route expects it
                },
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        team.imagePath,
                        width: 50,
                        height: 50,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'TeamLogos/Barcelona.png',
                          height: 50,
                          width: 50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            // '1. Fußballclub Heidenheim 1846 e.V',
                            style: Heading3.style,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Text(
                                "$leagueName ${rank != null ? ordinal(rank) : '-'}",
                                style: Body2.style,
                              ),
                              const Icon(Icons.arrow_drop_up,
                                  color: Colors.green),
                              const Text("1", style: Body2.style),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // NEXT MATCH (from API)
              if (match != null)
                GestureDetector(
                    onTap: () {
                      final status = match.status.name;
                      context.push('/match/${match.fixtureId}?status=$status');
                    },
                    child: MatchCard(
                      match: match,
                      leagueName: leagueNames[match.leagueId],
                    )),

              const SizedBox(height: 12),

              // LAST MATCH
              if (team.lastMatch != null)
                GestureDetector(
                  onTap: () {
                    final last = team.lastMatch!;
                    final status = last.status.name;
                    context.push('/match/${last.fixtureId}?status=$status');
                  },
                  child: () {
                    final last = team.lastMatch!;
                    final home = mockTeamById(last.homeTeamId);
                    final away = mockTeamById(last.awayTeamId);
                    return MatchCard2(
                      date: DateFormat('EEE, MMM d h:mm a').format(DateTime.parse(last.startingAt).toLocal()),
                      venue: '',
                      team1shortname: home.shortCode ?? home.name,
                      team1Logo: home.imagePath ?? '',
                      team2shortname: away.shortCode ?? away.name,
                      team2Logo: away.imagePath ?? '',
                      homeScore: last.homeScore ?? 0,
                      awayScore: last.awayScore ?? 0,
                    );
                  }(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CalendarEvent {
  final String logoAsset;
  final Color dotColor;
  final int fixtureId;
  final String status; // 'past' | 'live' | 'upcoming'

  CalendarEvent({
    required this.logoAsset,
    required this.dotColor,
    required this.fixtureId,
    required this.status,
  });
}

class HardcodedCalendar extends StatefulWidget {
  final List<Fixture> allMatches;

  const HardcodedCalendar({super.key, required this.allMatches});

  @override
  State<HardcodedCalendar> createState() => _HardcodedCalendarState();
}

class _HardcodedCalendarState extends State<HardcodedCalendar> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Dynamic events generator - automatically creates events for any month/year
  Map<DateTime, List<CalendarEvent>> _generateEventsForMonth(DateTime month) {
    final events = <DateTime, List<CalendarEvent>>{};

    for (final fixture in widget.allMatches) {
      final dt = DateTime.parse(fixture.startingAt).toLocal();
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      if (dt.year != month.year || dt.month != month.month) continue;

      final team = mockTeamById(fixture.homeTeamId);
      final color = switch (fixture.competitionType) {
        CompetitionType.league => Colors.red,
        CompetitionType.europe => Colors.blue,
        CompetitionType.cup => Colors.green,
      };

      events.putIfAbsent(dateOnly, () => []).add(CalendarEvent(
        logoAsset: team.imagePath ?? '',
        dotColor: color,
        fixtureId: fixture.fixtureId,
        status: fixture.status.name,
      ));
    }

    return events;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final events = _generateEventsForMonth(_currentMonth);

    return Column(
      children: [
        // Calendar container
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(28),
          ),
          margin: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: _previousMonth,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Text(_getMonthName(_currentMonth.month),
                        style: Heading3.style),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Calendar grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // thin divider under the month title
                    _buildCalendarGrid(events),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),

        // Legend outside the calendar
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegendDot(Colors.red, 'League'),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.blue, 'UCL'),
              const SizedBox(width: 16),
              _buildLegendDot(Colors.green, 'Cup'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: Body2_b.style),
      ],
    );
  }

  Widget _buildCalendarGrid(Map<DateTime, List<CalendarEvent>> events) {
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // Mon=1..Sun=7
    final startDay = firstWeekday % 7; // Sun=0
    final totalCells = startDay + daysInMonth;
    final weekCount = (totalCells / 7).ceil(); // 4..6 rows
    final lastDayIndex = (startDay + daysInMonth - 1) % 7; // 0..6 index within its row

    return Column(
      children: [
        // top divider under the month title; starts at the first real day
        LayoutBuilder(
          builder: (context, constraints) {
            final cellW = constraints.maxWidth / 7.0;
            return Container(
              margin: EdgeInsets.only(left: startDay * cellW + 12.0),
              height: 1,
              color: Colors.grey.shade600,
            );
          },
        ),
        const SizedBox(height: 8),

        for (int week = 0; week < weekCount; week++)
          Column(
            children: [
              Row(
                children: [
                  for (int day = 0; day < 7; day++)
                    Expanded(
                      child: _buildCalendarCell(
                        week,
                        day,
                        startDay,
                        daysInMonth,
                        events,
                      ),
                    ),
                ],
              ),

              // Row divider: full width except
              // first row: start under day 1 (left inset)
              // penultimate row: stop at last real day (right inset)
              if (week < weekCount - 1)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cellW = constraints.maxWidth / 7.0;
                    const left = 12.0;
                    final right = (week == weekCount - 2)
                        ? (6 - lastDayIndex) * cellW
                        : 12.0;
                    return Container(
                      margin: EdgeInsets.only(left: left, right: right),
                      height: 1,
                      color: Colors.grey.shade600,
                    );
                  },
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCalendarCell(
      int week,
      int dayOfWeek,
      int startDay,
      int daysInMonth,
      Map<DateTime, List<CalendarEvent>> events,
      ) {
    final dayNumber = week * 7 + dayOfWeek - startDay + 1;

    // Don't show days outside the current month
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return SizedBox(
        height: 90,
        child: const SizedBox(),
      );
    }

    final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
    final dayEvents = events[date] ?? [];
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final isHighlighted = date == todayDateOnly;
    // Flutter의 weekday: Monday = 1, Sunday = 7
    final isWeekend = date.weekday == DateTime.saturday ||
        date.weekday == DateTime.sunday;

    return GestureDetector(
      onTap: dayEvents.isNotEmpty
          ? () => context.push(
          '/match/${dayEvents.first.fixtureId}?status=${dayEvents.first.status}')
          : null,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.black : Colors.transparent,
          borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNumber.toString(),
              style: Heading4.style.copyWith(
                color: isWeekend ? Colors.grey.shade500 : Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (dayEvents.isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                height: 28,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.network(
                      dayEvents.first.logoAsset,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Image.asset(
                        randomTeamLogo(),
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 3,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dayEvents.first.dotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class MyHighlights extends StatefulWidget {
  const MyHighlights({super.key, this.highlights});

  final highlights;

  @override
  State<MyHighlights> createState() => _MyHighlightsState();
}

class _MyHighlightsState extends State<MyHighlights> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // height: 300, // Fixed height to prevent overflow
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            widget.highlights?.length ?? 0,
                (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      widget.highlights![i][5]["image"] as String,
                      // Logo path
                      width: 119,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error,
                          color:
                          Colors.red), // Error handling for missing image
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 37,
                        child: Text(
                          widget.highlights![i][5]["title"] as String,
                          style: Body1_b.style,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${widget.highlights![i][5]["source"]} ${widget.highlights![i][5]["time"]}",
                        style: Body2.style,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyNews extends StatefulWidget {
  const MyNews({super.key, this.news});

  final news;

  @override
  State<MyNews> createState() => _MyNewsState();
}

class _MyNewsState extends State<MyNews> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // height: 300, // Fixed height to prevent overflow
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            widget.news?.length ?? 0,
                (i) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      widget.news![i][5]["image"] as String, // Logo path
                      width: 119,
                      height: 68,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.error,
                          color:
                          Colors.red), // Error handling for missing image
                    ),
                  ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 210,
                        height: 37,
                        child: Text(
                          widget.news![i][5]["title"] as String,
                          style: Body1_b.style,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${widget.news![i][5]["source"]} ${widget.news![i][5]["time"]}",
                        style: Body2.style,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}