import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/teamdata.dart';
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
  // Data moved inside the State class
  final List<Map<String, dynamic>> _followingTeams = [
    {'name': 'FC Barcelona', 'league': 'La Liga 1st', 'logo': 'TeamLogos/Barcelona.png', 'isSelected': true},
    {'name': 'Real Madrid', 'league': 'La Liga 2nd', 'logo': 'TeamLogos/RealMadrid.png', 'isSelected': false},
    {'name': 'Atletico Madrid', 'league': 'La Liga 3rd', 'logo': 'TeamLogos/AtleticoMadrid.png', 'isSelected': false},
    {'name': 'Sevilla FC', 'league': 'La Liga 4th', 'logo': 'TeamLogos/Sevilla.png', 'isSelected': false},
  ];

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
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.error, color: Colors.white),
                    ),
                  ),
                  title: Text(team['name'], style: Body1_b.style),
                  subtitle: Text(team['league'], style: Body2.style),
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
    final team = teams[0]; // Show only the first favorite team
    final match = team.nextMatch;
    final rank = team.standing?['rank'];
    final leagueName = leagueNames[team.leagueId] ?? 'Unknown League';

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
                        errorBuilder: (_, __, ___) =>
                        const Icon(Icons.error, color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(team.name, style: Heading3.style),
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // NEXT MATCH (from API)
              if (match != null)
                GestureDetector(
                    onTap: () {
                      final matchDateTime = DateTime.parse(match.date);
                      final status = determineMatchStatus(matchDateTime);
                      context.push('/match/${match.id}?status=$status');
                    },
                    child: MatchCard(
                      match: match,
                      leagueName: leagueNames[team.leagueId], // 선택
                    )),

              const SizedBox(height: 12),

              // HARDCODED SECOND MATCH (still dummy)
              GestureDetector(
                onTap: () {
                  const matchId = "300";
                  final matchDateTime = DateTime(2025, 9, 20, 15, 30);
                  final status = determineMatchStatus(matchDateTime);
                  context.push('/match/$matchId?status=$status');
                },
                child: MatchCard2(
                  date: 'Sat, Sep 20 3:30 PM',
                  venue: 'Venue Name',
                  team1shortname: "FCB",
                  team1Logo: 'TeamLogos/Barcelona.png',
                  team2shortname: "GIR",
                  team2Logo: 'TeamLogos/Girona.png',
                ),
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
  CalendarEvent(this.logoAsset, this.dotColor);
}

class HardcodedCalendar extends StatefulWidget {
  const HardcodedCalendar({super.key});

  @override
  State<HardcodedCalendar> createState() => _HardcodedCalendarState();
}

class _HardcodedCalendarState extends State<HardcodedCalendar> {
  DateTime _currentMonth =
  DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Dynamic events generator - automatically creates events for any month/year
  Map<DateTime, List<CalendarEvent>> _generateEventsForMonth(DateTime month) {
    final events = <DateTime, List<CalendarEvent>>{};
    final random = Random(month.month + month.year * 12); // Seed for consistent results

    final teamLogos = [
      'TeamLogos/Barcelona.png',
      'TeamLogos/Barcelona.png',
      'TeamLogos/Barcelona.png',
      'TeamLogos/Barcelona.png',
    ];

    final colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final eventDays = <int>[];

    // Generate 4-8 random event days per month
    final numEvents = 4 + random.nextInt(5);
    while (eventDays.length < numEvents) {
      final day = 1 + random.nextInt(daysInMonth);
      if (!eventDays.contains(day)) {
        eventDays.add(day);
      }
    }

    // Create events for selected days
    for (final day in eventDays) {
      final logo = teamLogos[random.nextInt(teamLogos.length)];
      final color = colors[random.nextInt(colors.length)];
      events[DateTime(month.year, month.month, day)] = [
        CalendarEvent(logo, color)
      ];
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
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "UCL",
                style: Body2_b.style,
              ),
              const SizedBox(width: 16),
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "CDR",
                style: Body2_b.style,
              ),
            ],
          ),
        ),
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
        // ── top divider under the month title; starts at the first real day
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
              //   • first row: start under day 1 (left inset)
              //   • penultimate row: stop at last real day (right inset)
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
    return Container(
      height: 90,
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.black : Colors.transparent,
        borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Day number
          Text(
            dayNumber.toString(),
            style: Heading4.style.copyWith(
              color: isWeekend ? Colors.grey.shade500 : Colors.white,
            ),
          ),

          const SizedBox(height: 8),

          // Event logo and dot
          if (dayEvents.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 28,
              child: Stack(
                children: [
                  Positioned(
                    child: Image.asset(
                      dayEvents.first.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          color: dayEvents.first.dotColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(Icons.sports_soccer,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 8,
                      height: 8,
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
            const SizedBox(height: 28), // Maintain spacing when no events
        ],
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