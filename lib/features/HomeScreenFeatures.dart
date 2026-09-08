import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/home/mock/home_content_catalog.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import '../models/team_overview.dart';
import '../models/fixture.dart';
import '../models/home_content_item.dart';
import "package:onetouch/features/helper.dart";
import "package:onetouch/core/style.dart";
import "package:onetouch/core/stylesheet.dart";
import 'package:onetouch/core/user_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final appColors = AppColors.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      backgroundColor: appColors.cardBackground,
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
                  backgroundColor: colorScheme.onSurface,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "YES, SYNC IT!",
                  style: Body2_b.style.copyWith(color: colorScheme.onPrimary),
                ),
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
  final int initialFavoriteTeamId;
  final void Function(int teamId) onSwitch;

  const TeamSelectionSheet({
    super.key,
    required this.initialFavoriteTeamId,
    required this.onSwitch,
  });

  // Static helper to show the sheet easily from anywhere
  static void show(
    BuildContext context, {
    required int initialFavoriteTeamId,
    required void Function(int teamId) onSwitch,
  }) {
    final appColors = AppColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: appColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => TeamSelectionSheet(
        initialFavoriteTeamId: initialFavoriteTeamId,
        onSwitch: onSwitch,
      ),
    );
  }

  @override
  State<TeamSelectionSheet> createState() => _TeamSelectionSheetState();
}

class _TeamSelectionSheetState extends State<TeamSelectionSheet> {
  late List<Map<String, dynamic>> _followingTeams;

  @override
  void initState() {
    super.initState();
    _followingTeams = currentUserPreferences.followedTeamIds.value.map((id) {
      final t = teamRepository.requireById(id);
      return <String, dynamic>{
        'id': id,
        'name': t.name,
        'league': teamCompetitionContextResolver.labelFor(id),
        'logo': t.imagePath ?? '',
        'isSelected': id == widget.initialFavoriteTeamId,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 48),
              Expanded(
                child: Text(
                  "Following Teams",
                  style: Heading5.style,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurface),
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
                    child: Image.network(
                      team['logo'],
                      width: 24,
                      height: 24,
                      errorBuilder: (context, error, stackTrace) =>
                          teamLogoFallback(team['id'] as int, size: 24),
                    ),
                  ),
                  title: Text(
                    team['name'],
                    style: Body1_b.style,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(team['league'] ?? '', style: Body2.style),
                  trailing: team['isSelected']
                      ? Icon(Icons.check, color: colorScheme.onSurface)
                      : null,
                  onTap: () {
                    setState(() {
                      for (var t in _followingTeams) {
                        t['isSelected'] = false;
                      }
                      team['isSelected'] = true;
                    });
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
                final selected = _followingTeams.firstWhere(
                  (t) => t['isSelected'] == true,
                  orElse: () => _followingTeams.first,
                );
                widget.onSwitch(selected['id'] as int);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.onSurface,
                foregroundColor: colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "SWITCH",
                style: Body2_b.style.copyWith(color: colorScheme.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FavoriteTeamCard extends StatelessWidget {
  final TeamOverview team;

  const FavoriteTeamCard({super.key, required this.team});

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final match = team.liveMatch ?? team.nextMatch;
    final leagueId = match?.competitionId ?? team.lastMatch?.competitionId;
    final leagueName = leagueId == null
        ? ''
        : competitionRepository.findById(leagueId)?.name ?? '';
    final rank = leagueId != null
        ? standingRepository.findForTeam(leagueId, team.id)?.position
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Material(
        color: appColors.cardBackground,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          key: const ValueKey('home-favorite-team-surface'),
          width: 375,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: appColors.cardBackground,
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
                            teamLogoFallback(team.id, size: 50),
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
                              Flexible(
                                child: Text(
                                  "$leagueName ${rank != null ? ordinal(rank) : '-'}",
                                  style: Body2.style,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                      leagueName: competitionRepository
                          .findById(match.competitionId)
                          ?.name,
                    )),

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
                    final home =
                        teamRepository.findByIdOrUnknown(last.homeTeamId);
                    final away =
                        teamRepository.findByIdOrUnknown(last.awayTeamId);
                    return MatchCard2(
                      date: DateFormat('EEE, MMM d h:mm a')
                          .format(DateTime.parse(last.startingAt).toLocal()),
                      venue: '',
                      team1shortname: home.shortCode ?? home.name,
                      team1Logo: home.imagePath ?? '',
                      team1Id: home.teamId,
                      team2shortname: away.shortCode ?? away.name,
                      team2Logo: away.imagePath ?? '',
                      team2Id: away.teamId,
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
  final String opponentLogoUrl;
  final int opponentTeamId;
  final Color dotColor;
  final int fixtureId;
  final String status; // 'past' | 'live' | 'upcoming'

  CalendarEvent({
    required this.opponentLogoUrl,
    required this.opponentTeamId,
    required this.dotColor,
    required this.fixtureId,
    required this.status,
  });
}

class FixtureCalendar extends StatefulWidget {
  final List<Fixture> allMatches;
  final int favoriteTeamId;

  const FixtureCalendar({
    super.key,
    required this.allMatches,
    required this.favoriteTeamId,
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

    for (final fixture in widget.allMatches) {
      final favoriteIsHome = fixture.homeTeamId == widget.favoriteTeamId;
      final favoriteIsAway = fixture.awayTeamId == widget.favoriteTeamId;
      if (!favoriteIsHome && !favoriteIsAway) continue;
      if (!addedFixtureIds.add(fixture.fixtureId)) continue;

      final dt = DateTime.parse(fixture.startingAt).toLocal();
      final dateOnly = DateTime(dt.year, dt.month, dt.day);
      if (dt.year != month.year || dt.month != month.month) continue;

      final opponentTeamId =
          favoriteIsHome ? fixture.awayTeamId : fixture.homeTeamId;
      final opponent = teamRepository.findByIdOrUnknown(opponentTeamId);
      final color = switch (fixture.competitionType) {
        CompetitionType.league => Colors.red,
        CompetitionType.europe => Colors.blue,
        CompetitionType.cup => Colors.green,
      };

      events.putIfAbsent(dateOnly, () => []).add(CalendarEvent(
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
              '/match/${dayEvents.first.fixtureId}?status=${dayEvents.first.status}')
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

class MyHighlights extends StatelessWidget {
  const MyHighlights({super.key, required this.highlights});

  final List<HomeContentItem> highlights;

  @override
  Widget build(BuildContext context) => _HomeContentList(items: highlights);
}

class MyNews extends StatelessWidget {
  const MyNews({super.key, required this.news});

  final List<HomeContentItem> news;

  @override
  Widget build(BuildContext context) => _HomeContentList(items: news);
}

class _HomeContentList extends StatelessWidget {
  const _HomeContentList({required this.items});

  final List<HomeContentItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(
          items.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _HomeContentCard(
              key: ValueKey('${items[index].destinationUrl}-$index'),
              item: items[index],
              fallback: homeContentFallbackItems[
                  index % homeContentFallbackItems.length],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeContentCard extends StatefulWidget {
  const _HomeContentCard({
    super.key,
    required this.item,
    required this.fallback,
  });

  final HomeContentItem item;
  final HomeContentItem fallback;

  @override
  State<_HomeContentCard> createState() => _HomeContentCardState();
}

class _HomeContentCardState extends State<_HomeContentCard> {
  bool _useFallback = false;

  @override
  void didUpdateWidget(_HomeContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.imageUrl != widget.item.imageUrl) {
      _useFallback = false;
    }
  }

  Future<void> _openDestination(String? value) async {
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _handleImageError() {
    if (_useFallback) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_useFallback) setState(() => _useFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _useFallback ? widget.fallback : widget.item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.destinationUrl == null
          ? null
          : () => _openDestination(item.destinationUrl),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _buildImage(),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 37,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Body1_b.style,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.source} ${item.timeLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Body2.style,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = widget.item.imageUrl;
    if (!_useFallback && imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        width: 119,
        height: 68,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _handleImageError();
          return _fallbackImage();
        },
      );
    }
    return _fallbackImage();
  }

  Widget _fallbackImage() {
    return Image.asset(
      widget.fallback.fallbackAsset,
      width: 119,
      height: 68,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox(
        width: 119,
        height: 68,
        child: Icon(Icons.error, color: Colors.red),
      ),
    );
  }
}
