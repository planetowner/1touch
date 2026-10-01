part of 'home_screen_features.dart';

class CalendarEvent {
  final Fixture fixture;
  final String opponentLogoUrl;
  final int opponentTeamId;
  final Color? dotColor;
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

/// Include cup competitions found in this month's fixtures even when the
/// catalog's current team memberships only include the domestic league.
List<Competition> calendarCompetitionsForFixtures({
  required List<Competition> participatingCompetitions,
  required List<Competition> catalogCompetitions,
  required List<HomeCalendarFixture> fixtures,
}) {
  final competitionsById = {
    for (final competition in participatingCompetitions)
      competition.competitionId: competition,
  };
  final catalogById = {
    for (final competition in catalogCompetitions)
      competition.competitionId: competition,
  };
  for (final match in fixtures) {
    final fixture = match.fixture;
    if (fixture.competitionType == CompetitionType.league) continue;
    final competition = catalogById[fixture.competitionId];
    if (competition != null) {
      competitionsById[competition.competitionId] = competition;
    }
  }
  return competitionsById.values.toList(growable: false);
}

class FixtureCalendar extends StatefulWidget {
  final List<HomeCalendarFixture> allMatches;
  final int favoriteTeamId;
  final List<Competition> participatingCompetitions;
  final ValueChanged<DateTime>? onMonthChanged;
  final DateTime? selectedMonth;

  const FixtureCalendar({
    super.key,
    required this.allMatches,
    required this.favoriteTeamId,
    required this.participatingCompetitions,
    this.onMonthChanged,
    this.selectedMonth,
  });

  @override
  State<FixtureCalendar> createState() => _FixtureCalendarState();
}

class _FixtureCalendarState extends State<FixtureCalendar> {
  late DateTime _currentMonth =
      _monthStart(widget.selectedMonth ?? DateTime.now());

  static DateTime _monthStart(DateTime date) =>
      DateTime(date.year, date.month, 1);

  @override
  void didUpdateWidget(covariant FixtureCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMonth case final selectedMonth?) {
      if (_monthStart(selectedMonth) != _currentMonth) {
        _currentMonth = _monthStart(selectedMonth);
      }
    }
  }

  // 유럽대항전 → 자국 컵 → 잉글랜드 리그컵 순서로 색을 배정해요.
  static int _competitionPriority(Competition competition) =>
      switch (competition.competitionId) {
        2 || 5 || 2286 => 0,
        27 => 2,
        _ => 1,
      };

  static String _competitionLegendLabel(Competition competition) =>
      normalizeCompetitionDisplayLabel(
          competition.shortCode ?? competition.name);

  Map<DateTime, List<CalendarEvent>> _generateEventsForMonth(
      DateTime month, Map<int, Color> competitionColors) {
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

      events.putIfAbsent(dateOnly, () => []).add(CalendarEvent(
            fixture: fixture,
            opponentLogoUrl: opponent.imagePath ?? '',
            opponentTeamId: opponent.teamId,
            dotColor: fixture.competitionType == CompetitionType.league
                ? null
                : competitionColors[fixture.competitionId],
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
    // 리그는 로고만 보여주고, 범례와 점 색상은 컵 대회에만 사용해요.
    final leagueCompetitionIds = {
      ...TeamPageEligibility.domesticBigFiveCompetitionIds,
      for (final match in widget.allMatches)
        if (match.fixture.competitionType == CompetitionType.league)
          match.fixture.competitionId,
    };
    final competitions = widget.participatingCompetitions
        .where((competition) =>
            !leagueCompetitionIds.contains(competition.competitionId))
        .toList()
      ..sort((a, b) {
        final priority =
            _competitionPriority(a).compareTo(_competitionPriority(b));
        return priority != 0
            ? priority
            : a.competitionId.compareTo(b.competitionId);
      });
    const palette = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
    ];
    final competitionColors = {
      for (var i = 0; i < competitions.length; i++)
        competitions[i].competitionId: palette[i % palette.length],
    };
    final events = _generateEventsForMonth(_currentMonth, competitionColors);
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Calendar container
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Container(
            key: const ValueKey('fixture-calendar-card'),
            decoration: BoxDecoration(
              color: appColors.cardBackground,
              borderRadius: BorderRadius.circular(28),
              boxShadow: appCardShadows(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: IconButton(
                            onPressed: _previousMonth,
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.chevron_left,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 5,
                        child: Text(
                          tr(context, _getMonthName(_currentMonth.month)),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Heading3.style,
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: IconButton(
                            onPressed: _nextMonth,
                            style: IconButton.styleFrom(
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(
                              Icons.chevron_right,
                              color: colorScheme.onSurface,
                              size: 24,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints.tightFor(
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Calendar grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // thin divider under the month title
                      _buildCalendarGrid(events),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Legend outside the calendar
        if (competitions.isNotEmpty)
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            alignment: Alignment.centerRight,
            child: FittedBox(
              key: const ValueKey('fixture-calendar-legends'),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < competitions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    _buildLegendDot(
                      competitionColors[competitions[i].competitionId]!,
                      _competitionLegendLabel(competitions[i]),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      key: ValueKey('calendar-legend-$label'),
      mainAxisSize: MainAxisSize.min,
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
              if (week < weekCount - 1) const SizedBox(height: 8),
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
        height: 75,
        child: const SizedBox(),
      );
    }

    final date = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
    final dayEvents = events[date] ?? [];
    // A date can contain more than one fixture. Keep the cup fixture visible
    // when a league fixture happens to be first in the API response.
    final displayedEvent = dayEvents.cast<CalendarEvent?>().firstWhere(
          (event) => event!.dotColor != null,
          orElse: () => dayEvents.isEmpty ? null : dayEvents.first,
        );
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);
    final isHighlighted = date == todayDateOnly;
    // Flutter의 weekday: Monday = 1, Sunday = 7
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: displayedEvent != null
          ? () => context.push(
                '/match/${displayedEvent.fixtureId}?status=${displayedEvent.status}',
                extra: displayedEvent.fixture,
              )
          : null,
      child: SizedBox(
        height: 75,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 40),
            child: Container(
              width: 40,
              height: 70,
              decoration: BoxDecoration(
                color:
                    isHighlighted ? colorScheme.onSurface : Colors.transparent,
                borderRadius: isHighlighted ? BorderRadius.circular(4) : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      dayNumber.toString(),
                      maxLines: 1,
                      softWrap: false,
                      style: Heading4.style.copyWith(
                        color: isHighlighted
                            ? colorScheme.onPrimary
                            : isWeekend
                                ? appColors.mutedForeground
                                : colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (displayedEvent != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.network(
                            displayedEvent.opponentLogoUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => teamLogoFallback(
                              displayedEvent.opponentTeamId,
                              size: 28,
                            ),
                          ),
                          if (displayedEvent.dotColor != null)
                            Positioned(
                              top: 0,
                              right: 3,
                              child: Container(
                                key: ValueKey(
                                    'calendar-fixture-dot-${displayedEvent.fixtureId}'),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: displayedEvent.dotColor,
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
          ),
        ),
      ),
    );
  }
}
