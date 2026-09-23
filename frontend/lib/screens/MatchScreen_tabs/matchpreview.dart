import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_providers;
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/standings/api_standing_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository.dart';
import 'package:onetouch/models/standing.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/data/team_attributes/team_attribute_repository.dart';
import 'package:onetouch/features/team/attributes/match_attribute_comparison.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class _StandingRow {
  final int pos;
  final String name;
  final int teamId;
  final String? logoUrl;
  final String mp;
  final String w;
  final String d;
  final String l;
  final bool highlight;

  const _StandingRow({
    required this.pos,
    required this.name,
    required this.teamId,
    required this.logoUrl,
    required this.mp,
    required this.w,
    required this.d,
    required this.l,
    required this.highlight,
  });
}

class MatchPreviewTab extends StatefulWidget {
  final Fixture fixture;
  final FixtureRepository? fixtureRepository;
  final BettingController bettingController;
  final TeamAttributeRepository? attributeRepository;
  final StandingRepository? standingRepository;

  const MatchPreviewTab({
    super.key,
    required this.fixture,
    required this.bettingController,
    this.fixtureRepository,
    this.attributeRepository,
    this.standingRepository,
  });

  @override
  State<MatchPreviewTab> createState() => _MatchPreviewTabState();
}

class _MatchPreviewTabState extends State<MatchPreviewTab> {
  Fixture? _latestH2H;
  bool _isLatestH2HLoading = true;
  bool _hasLatestH2HError = false;
  int _latestH2HRequestId = 0;
  List<Standing> _currentStandings = const [];
  bool _standingsLoading = true;
  bool _standingsFailed = false;
  int _standingsRequestId = 0;

  FixtureRepository get _fixtureRepository =>
      widget.fixtureRepository ?? fixture_providers.fixtureRepository;

  @override
  void initState() {
    super.initState();
    _loadLatestHeadToHead();
    _loadCurrentStandings();
  }

  @override
  void didUpdateWidget(MatchPreviewTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixture.competitionId != oldWidget.fixture.competitionId ||
        widget.standingRepository != oldWidget.standingRepository) {
      _loadCurrentStandings();
    }
    if (widget.fixture.fixtureId != oldWidget.fixture.fixtureId ||
        widget.fixtureRepository != oldWidget.fixtureRepository) {
      _loadLatestHeadToHead();
    }
  }

  Future<void> _loadLatestHeadToHead() async {
    final requestId = ++_latestH2HRequestId;
    final fixtureId = widget.fixture.fixtureId;
    final repository = _fixtureRepository;

    setState(() {
      _latestH2H = null;
      _isLatestH2HLoading = true;
      _hasLatestH2HError = false;
    });

    try {
      final loaded = await repository.loadHeadToHead(fixtureId, limit: 1);
      if (!mounted || requestId != _latestH2HRequestId) return;
      setState(() {
        _latestH2H = loaded.firstOrNull;
        _isLatestH2HLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _latestH2HRequestId) return;
      setState(() {
        _hasLatestH2HError = true;
        _isLatestH2HLoading = false;
      });
    }
  }

  Future<void> _loadCurrentStandings() async {
    final requestId = ++_standingsRequestId;
    setState(() {
      _currentStandings = const [];
      _standingsLoading = true;
      _standingsFailed = false;
    });
    try {
      final repository = widget.standingRepository ?? apiStandingRepository;
      // Omitting seasonId lets the API select the competition's current season.
      final rows =
          await repository.loadForCompetition(widget.fixture.competitionId);
      if (!mounted || requestId != _standingsRequestId) return;
      setState(() {
        _currentStandings = rows;
        _standingsLoading = false;
      });
    } on Object {
      if (!mounted || requestId != _standingsRequestId) return;
      setState(() {
        _standingsLoading = false;
        _standingsFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final homeTeam = fixtureHomeTeam(widget.fixture, teamRepository);
    final awayTeam = fixtureAwayTeam(widget.fixture, teamRepository);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildHeader(),
          const SizedBox(height: 48),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 0),
            child: Text(
              tr(context, "BET"),
              style: Body2_b.style,
            ),
          ),
          const SizedBox(height: 16),

          // Using the extracted widget from the new file
          MatchBettingSection(
            controller: widget.bettingController,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
          ),

          const SizedBox(height: 48),
          MatchAttributeComparison(
            homeTeamId: widget.fixture.homeTeamId,
            awayTeamId: widget.fixture.awayTeamId,
            homeTeamName: homeTeam.displayName,
            awayTeamName: awayTeam.displayName,
            repository: widget.attributeRepository,
          ),
          const SizedBox(height: 48),
          _buildLatestH2H(),
          const SizedBox(height: 48),
          _buildStandingTable(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final home = fixtureHomeTeam(widget.fixture, teamRepository);
    final away = fixtureAwayTeam(widget.fixture, teamRepository);
    final kickoff = widget.fixture.kickoff?.toLocal();
    final date = kickoff == null
        ? tr(context, 'Date TBD')
        : DateFormat('EEE, MMM d').format(kickoff);
    final time = kickoff == null
        ? tr(context, 'Time TBD')
        : DateFormat('h:mm a').format(kickoff);
    final roundLabel =
        widget.fixture.displayRoundLabel ?? tr(context, 'Round TBD');

    return Row(
      children: [
        Expanded(
          child: _buildTeamBlock(
            home.displayName,
            home.imagePath ?? '',
            home.teamId,
          ),
        ),
        SizedBox(
          width: 104,
          child: Column(
            children: [
              Text(roundLabel,
                  style: Body2_b.style, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Container(
                width: 24,
                height: 1,
                color: foreground,
              ),
              const SizedBox(height: 8),
              Text(date, style: Body2_b.style, textAlign: TextAlign.center),
              Text(time, style: Body2_b.style),
            ],
          ),
        ),
        Expanded(
          child: _buildTeamBlock(
            away.displayName,
            away.imagePath ?? '',
            away.teamId,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamBlock(String name, String logoPath, int teamId) {
    return Column(
      children: [
        GestureDetector(
          // The match screen sits on the root navigator (see main.dart's
          // '/match/:matchId'), but '/team/:id' belongs to the bottom-nav
          // shell's own navigator — push() would land there invisibly,
          // behind this screen. go() replaces the location so it surfaces.
          onTap: isTeamPageSupported(teamId)
              ? () => openTeamPage(context, teamId)
              : null,
          child: Image.network(
            logoPath,
            width: 72,
            height: 72,
            errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 72),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Body1.style,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLatestH2H() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final h2h = _latestH2H;

    if (_isLatestH2HLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'LATEST H2H'), style: Body2_b.style),
          SizedBox(height: 16),
          Padding(
            key: ValueKey('match-preview-h2h-loading'),
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_hasLatestH2HError) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'LATEST H2H'), style: Body2_b.style),
          const SizedBox(height: 16),
          Center(
            key: const ValueKey('match-preview-h2h-error'),
            child: Column(
              children: [
                Text(
                  tr(context, 'Unable to load the latest meeting.'),
                  style: Body2.style,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadLatestHeadToHead,
                  child: Text(tr(context, 'RETRY')),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (h2h == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'LATEST H2H'), style: Body2_b.style),
          SizedBox(height: 16),
          Center(
            key: ValueKey('match-preview-h2h-empty'),
            child: Text(
              tr(context, 'No previous meetings found.'),
              style: Body2.style,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final home = fixtureHomeTeam(h2h, teamRepository);
    final away = fixtureAwayTeam(h2h, teamRepository);
    final kickoff = h2h.kickoff?.toLocal();
    final date = kickoff == null
        ? tr(context, 'Date TBD')
        : DateFormat('EEE, MMM d').format(kickoff);
    final time = kickoff == null
        ? tr(context, 'Time TBD')
        : DateFormat('h:mm a').format(kickoff);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "LATEST H2H"), style: Body2_b.style),
        const SizedBox(height: 16),
        GestureDetector(
          key: const ValueKey('match-preview-h2h-card'),
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(
            '/match/${h2h.fixtureId}?status=${h2h.status.name}',
            extra: h2h,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.lightGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: appCardShadows(context),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final homeTeam = _buildSimpleTeamCol(
                  home.shortCode ?? home.name,
                  home.imagePath ?? '',
                  home.teamId,
                );
                final awayTeam = _buildSimpleTeamCol(
                  away.shortCode ?? away.name,
                  away.imagePath ?? '',
                  away.teamId,
                );
                final homeScore =
                    _buildScoreBox(h2h.homeScore?.toString() ?? '-');
                final awayScore =
                    _buildScoreBox(h2h.awayScore?.toString() ?? '-');
                final kickoff = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(date, style: Body2.style, textAlign: TextAlign.center),
                    Text(time, style: Body2.style, textAlign: TextAlign.center),
                  ],
                );

                if (constraints.maxWidth < 300) {
                  return Column(
                    children: [
                      kickoff,
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: homeTeam),
                          const SizedBox(width: 8),
                          homeScore,
                          const SizedBox(width: 8),
                          awayScore,
                          const SizedBox(width: 8),
                          Expanded(child: awayTeam),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(child: homeTeam),
                          const SizedBox(width: 12),
                          homeScore,
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    kickoff,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          awayScore,
                          const SizedBox(width: 12),
                          Flexible(child: awayTeam),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimpleTeamCol(String name, String asset, int teamId) {
    return Column(
      children: [
        GestureDetector(
          onTap: isTeamPageSupported(teamId)
              ? () => openTeamPage(context, teamId)
              : null,
          child: Image.network(
            asset,
            width: 48,
            height: 48,
            errorBuilder: (_, __, ___) => teamLogoFallback(teamId, size: 48),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Body2.style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScoreBox(String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
          color: isDark ? Colors.black : AppPalette.lightGreyBox,
          borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: Heading3.style.copyWith(color: foreground)),
    );
  }

  Widget _buildStandingTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final surface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final league = competitionRepository.findById(widget.fixture.competitionId);
    final standings = _currentStandings;
    if (_standingsLoading || _standingsFailed || standings.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, 'STANDING'), style: Body2_b.style),
          const SizedBox(height: 16),
          if (_standingsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_standingsFailed)
            TextButton(
              onPressed: _loadCurrentStandings,
              child: Text(tr(context, "Unable to load standings. Retry")),
            )
          else
            Center(child: Text(tr(context, "Coming soon"))),
        ],
      );
    }

    final matchTeamIds = {
      widget.fixture.homeTeamId,
      widget.fixture.awayTeamId,
    };
    final leaders = standings.take(5).toList();
    final leaderIds = leaders.map((standing) => standing.teamId).toSet();
    final featured = standings
        .where((standing) =>
            matchTeamIds.contains(standing.teamId) &&
            !leaderIds.contains(standing.teamId))
        .toList();
    final visibleStandings = [...leaders, ...featured];
    final dividerIndex = featured.isEmpty ? -1 : leaders.length;
    final rows = visibleStandings.map((standing) {
      final repositoryTeam = teamRepository.findById(standing.teamId);
      final responseName = standing.teamName?.trim();
      final displayName = repositoryTeam?.shortCode ??
          (responseName?.isNotEmpty ?? false ? responseName! : null) ??
          repositoryTeam?.name ??
          'Unknown Team';
      return _StandingRow(
        pos: standing.position,
        name: displayName,
        teamId: standing.teamId,
        logoUrl: standing.teamLogo ?? repositoryTeam?.imagePath,
        mp: standing.matchesPlayed.toString(),
        w: standing.won.toString(),
        d: standing.draw.toString(),
        l: standing.lost.toString(),
        highlight: matchTeamIds.contains(standing.teamId),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(context, "STANDING"), style: Body2_b.style),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: appCardShadows(context),
          ),
          child: Column(
            children: [
              // HEADER BOX: rounded top corners only
              Container(
                key: const ValueKey('match-preview-standing-header'),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // League logo + name
                    Row(
                      children: [
                        Image.network(
                          league?.imagePath ?? '',
                          width: 24,
                          height: 24,
                          errorBuilder: (_, __, ___) => competitionLogoFallback(
                            widget.fixture.competitionId,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            league?.name ?? tr(context, 'Unknown'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Column labels
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text('#',
                              style: TextStyle(
                                  color: appColors.mutedForeground,
                                  fontSize: 13)),
                        ),
                        Expanded(
                          child: Text(tr(context, 'Club'),
                              style: TextStyle(
                                  color: appColors.mutedForeground,
                                  fontSize: 13)),
                        ),
                        ..._colLabel(tr(context, 'MP')),
                        ..._colLabel(tr(context, 'W')),
                        ..._colLabel(tr(context, 'D')),
                        ..._colLabel(tr(context, 'L')),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: appColors.divider),
                  ],
                ),
              ),
              // BODY BOX: rounded bottom corners only
              Container(
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  children: List.generate(rows.length, (i) {
                    final row = rows[i];
                    return Column(
                      children: [
                        if (i == dividerIndex)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                '• • •',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 11,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                        _buildStandingRowWidget(row),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _colLabel(String text) => [
        SizedBox(
          width: 32,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.of(context).mutedForeground,
              fontSize: 12,
            ),
          ),
        ),
      ];

  Widget _buildStandingRowWidget(_StandingRow row) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;
    final textStyle = TextStyle(
      color: foreground,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );
    final mutedStyle = TextStyle(
      color: row.highlight ? foreground : mutedForeground,
      fontSize: 13,
      fontWeight: row.highlight ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Position
          SizedBox(
            width: 28,
            child: Text(
              '${row.pos}',
              style: mutedStyle,
            ),
          ),
          // Logo + name
          Expanded(
            child: Row(
              children: [
                if (row.logoUrl != null && row.logoUrl!.isNotEmpty)
                  Image.network(
                    row.logoUrl!,
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) =>
                        teamLogoFallback(row.teamId, size: 20),
                  )
                else
                  teamLogoFallback(row.teamId, size: 20),
                const SizedBox(width: 8),
                Text(row.name, style: textStyle),
              ],
            ),
          ),
          // MP W D L
          for (final val in [row.mp, row.w, row.d, row.l])
            SizedBox(
              width: 32,
              child: Text(
                val,
                textAlign: TextAlign.center,
                style: mutedStyle,
              ),
            ),
        ],
      ),
    );
  }
}
