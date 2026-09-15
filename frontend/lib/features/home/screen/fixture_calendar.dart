part of 'home_screen_features.dart';

class CalendarEvent {
  final Fixture fixture;
  final String opponentLogoUrl;
  final int opponentTeamId;
  final Color dotColor;
  final int fixtureId;
  final String status; // 'past' | 'live' | 'upcoming'

  CalendarEvent({
    required this.fixture,
    required this.opponentLogoUrl,
    required this.opponentTeamId,
    required this.dotColor,
    required this.fixtureId,
    required this.status,
  });
}

class FixtureCalendar extends StatefulWidget {
  final List<HomeCalendarFixture> allMatches;
  final int favoriteTeamId;
  final ValueChanged<DateTime>? onMonthChanged;

  const FixtureCalendar({
    super.key,
    required this.allMatches,
    required this.favoriteTeamId,
    this.onMonthChanged,
  });

  @override
  State<FixtureCalendar> createState() => _FixtureCalendarState();
}

class _FixtureCalendarState extends State<FixtureCalendar> {
  DateTime _currentMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Dynamic events generator - automatically creates events for any month/year
  Map<DateTime, List<CalendarEvent>> _generateEventsForMonth(DateTime month) {
    final events = <DateTime, List<CalendarEvent>>{};
    final addedFixtureIds = <int>{};

    for (final calendarFixture in widget.allMatches) {
      final fixture = calendarFixture.fixture;
      final favoriteIsHome = fixture.homeTeamId == widget.favoriteTeamId;
      final favoriteIsAway = fixture.awayTeamId == widget.favoriteTeamId;
      if (!favoriteIsHome && !favoriteIsAway) continue;
      if (!addedFixtureIds.add(fixture.fixtureId)) continue;

      final kickoff = fixture.kickoff;
      if (kickoff == null) continue;
      final dt = kickoff.toLocal();
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      if (dt.year != month.year || dt.month != month.month) continue;

      final opponent = calendarFixture.opponent;
      final color = switch (fixture.competitionType) {
        CompetitionType.league => Colors.red,
        CompetitionType.europe => Colors.blue,
        CompetitionType.cup => Colors.green,
      };

      events.putIfAbsent(dateOnly, () => []).add(CalendarEvent(
            fixture: fixture,
            opponentLogoUrl: opponent.imagePath ?? '',
            opponentTeamId: opponent.teamId,
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
    widget.onMonthChanged?.call(_currentMonth);
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    widget.onMonthChanged?.call(_currentMonth);
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
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Calendar container
        Container(
          decoration: BoxDecoration(
            color: appColors.cardBackground,
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
                      icon: Icon(
                        Icons.chevron_left,
                        color: colorScheme.onSurface,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _getMonthName(_currentMonth.month),
                          style: Heading3.style,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _nextMonth,
                      icon: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurface,
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
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendDot(Colors.red, 'League'),
              _buildLegendDot(Colors.blue, 'Europe'),
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
    final daysInMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1)
        .weekday; // Mon=1..Sun=7
    final startDay = firstWeekday % 7; // Sun=0
    final totalCells = startDay + daysInMonth;
    final weekCount = (totalCells / 7).ceil(); // 4..6 rows
    final lastDayIndex =
        (startDay + daysInMonth - 1) % 7; // 0..6 index within its row

    return Column(
      children: [
        // top divider under the month title; starts at the first real day
        LayoutBuilder(
          builder: (context, constraints) {
            final cellW = constraints.maxWidth / 7.0;
            return Container(
              margin: EdgeInsets.only(left: startDay * cellW + 12.0),
              height: 1,
              color: AppColors.of(context).divider,
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
                      color: AppColors.of(context).divider,
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
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: dayEvents.isNotEmpty
          ? () => context.push(
                '/match/${dayEvents.first.fixtureId}?status=${dayEvents.first.status}',
                extra: dayEvents.first.fixture,
              )
          : null,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: isHighlighted ? colorScheme.onSurface : Colors.transparent,
          borderRadius: isHighlighted ? BorderRadius.circular(8) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayNumber.toString(),
              style: Heading4.style.copyWith(
                color: isHighlighted
                    ? colorScheme.onPrimary
                    : isWeekend
                        ? appColors.mutedForeground
                        : colorScheme.onSurface,
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
                      dayEvents.first.opponentLogoUrl,
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => teamLogoFallback(
                        dayEvents.first.opponentTeamId,
                        size: 28,
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
