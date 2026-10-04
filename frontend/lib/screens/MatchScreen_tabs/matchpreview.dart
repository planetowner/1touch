import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/team_navigation.dart';
import 'package:onetouch/core/user_preferences.dart';
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
import 'package:onetouch/features/match_info/relevant_standings.dart';
import 'package:onetouch/features/betting_widgets.dart';
import 'package:onetouch/features/betting/betting_controller.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class _StandingRow {
  final int pos;
  final String name;
  final int teamId;
  final String? logoUrl;
  final String pts;
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
    required this.pts,
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
    currentUserPreferences.favoriteTeamId.addListener(_handleFavoriteChanged);
    _loadLatestHeadToHead();
    _loadCurrentStandings();
  }

  @override
  void dispose() {
    currentUserPreferences.favoriteTeamId
        .removeListener(_handleFavoriteChanged);
    super.dispose();
  }

  void _handleFavoriteChanged() {
    if (mounted) setState(() {});
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
    final favoriteTeamId = currentUserPreferences.favoriteTeamId.value;
    final bettingAnchorTeamId =
        favoriteTeamId == homeTeam.teamId || favoriteTeamId == awayTeam.teamId
            ? favoriteTeamId
            : homeTeam.teamId;

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
          MatchBettingSection(
            controller: widget.bettingController,
            homeTeam: homeTeam,
            awayTeam: awayTeam,
            anchorTeamId: bettingAnchorTeamId,
          ),
          const SizedBox(height: 48),
          MatchAttributeComparison(
            homeTeamId: widget.fixture.homeTeamId,
            awayTeamId: widget.fixture.awayTeamId,
            homeTeamName: teamNameLabel(
                context, homeTeam.teamId, homeTeam.displayName,
                short: true),
            awayTeamName: teamNameLabel(
                context, awayTeam.teamId, awayTeam.displayName,
                short: true),
            repository: widget.attributeRepository,
          ),
          const SizedBox(height: 48),
          _buildLatestH2H(),
          const SizedBox(height: 48),
          _buildStandingTable(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final home = fixtureHomeTeam(widget.fixture, teamRepository);
    final away = fixtureAwayTeam(widget.fixture, teamRepository);
    final kickoff = widget.fixture.kickoff?.toLocal();
    final labels =
        matchKickoffLabels(kickoff, locale: Localizations.localeOf(context));
    final date = labels.date;
    final time = labels.time;
    final roundLabel = fixtureCompetitionLabel(context, widget.fixture) ??
        fixtureRoundLabel(widget.fixture,
            locale: Localizations.localeOf(context)) ??
        tr(context, 'Round TBD');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTeamBlock(
          const ValueKey('match-preview-home-team'),
          teamNameLabel(context, home.teamId, home.displayName, short: true),
          home.imagePath ?? '',
          home.teamId,
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
        _buildTeamBlock(
          const ValueKey('match-preview-away-team'),
          teamNameLabel(context, away.teamId, away.displayName, short: true),
          away.imagePath ?? '',
          away.teamId,
        ),
      ],
    );
  }

  Widget _buildTeamBlock(
      Key blockKey, String name, String logoPath, int teamId) {
    return SizedBox(
      key: blockKey,
      width: 72,
      child: Column(
        children: [
          GestureDetector(
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
      ),
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
            child: Center(child: FootballLoadingIndicator()),
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
                  child: Text(trUpper(context, 'Retry')),
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
    final relativeDate = relativeDateLabel(
      h2h.kickoff,
      locale: Localizations.localeOf(context),
    );

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
          child: MatchCard2(
            date: relativeDate,
            venue: '',
            team1shortname: home.shortCode ??
                teamNameLabel(context, home.teamId, home.name),
            team1Logo: home.imagePath ?? '',
            team1Id: home.teamId,
            team2shortname: away.shortCode ??
                teamNameLabel(context, away.teamId, away.name),
            team2Logo: away.imagePath ?? '',
            team2Id: away.teamId,
            homeScore: h2h.homeScore,
            awayScore: h2h.awayScore,
            backgroundColor: isDark ? AppPalette.darkGrey : AppPalette.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            dateTextStyle: Body2.style,
            showTitle: false,
            borderRadius: BorderRadius.circular(24),
            surfaceKey: const ValueKey('match-preview-h2h-surface'),
          ),
        ),
      ],
    );
  }

  Widget _buildStandingTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final headerSurface = isDark ? AppPalette.lightGrey : AppPalette.white;
    final bodySurface = isDark ? AppPalette.darkGrey : AppPalette.lightGreyBox;
    final league = competitionRepository.findById(widget.fixture.competitionId);
    final standings = _currentStandings;
    if (_standingsLoading || _standingsFailed || standings.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(trUpper(context, 'Standing'), style: Body2_b.style),
          const SizedBox(height: 16),
          if (_standingsLoading)
            const Center(child: FootballLoadingIndicator())
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
    final selection = selectRelevantMatchStandings(
      standings,
      homeTeamId: widget.fixture.homeTeamId,
      awayTeamId: widget.fixture.awayTeamId,
    );
    final visibleStandings = selection.standings;
    final dividerIndex = selection.dividerIndex;
    final rows = visibleStandings.map((standing) {
      final repositoryTeam = teamRepository.findById(standing.teamId);
      final responseName = standing.teamName?.trim();
      final displayName = teamNameLabel(
        context,
        standing.teamId,
        (responseName?.isNotEmpty ?? false ? responseName! : null) ??
            repositoryTeam?.name ??
            'Unknown Team',
      );
      return _StandingRow(
        pos: standing.position,
        name: displayName,
        teamId: standing.teamId,
        logoUrl: standing.teamLogo ?? repositoryTeam?.imagePath,
        pts: standing.points.toString(),
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
        Text(trUpper(context, "Standing"), style: Body2_b.style),
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
                  color: headerSurface,
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
                            competitionNameLabel(context, league?.competitionId,
                                league?.name ?? tr(context, 'Unknown')),
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
                          child: Text(
                            '#',
                            style: Body2.style.copyWith(color: foreground),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tr(context, 'Club'),
                            key: const ValueKey(
                              'match-preview-standing-club-header',
                            ),
                            style: Body2.style.copyWith(color: foreground),
                          ),
                        ),
                        ..._colLabel(
                          tr(context, 'PTS'),
                          key: const ValueKey(
                            'match-preview-standing-pts-header',
                          ),
                        ),
                        ..._colLabel(tr(context, 'MP')),
                        ..._colLabel(tr(context, 'W')),
                        ..._colLabel(tr(context, 'D')),
                        ..._colLabel(tr(context, 'L')),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
              // BODY BOX: rounded bottom corners only
              Container(
                key: const ValueKey('match-preview-standing-body'),
                decoration: BoxDecoration(
                  color: bodySurface,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
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

  List<Widget> _colLabel(String text, {Key? key}) => [
        SizedBox(
          key: key,
          width: 32,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Body2.style.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
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
                Expanded(
                  child: Text(
                    row.name,
                    key: ValueKey(
                      'match-preview-standing-team-${row.teamId}',
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
              ],
            ),
          ),
          // PTS MP W D L
          for (final entry in [
            (value: row.pts, stat: 'pts'),
            (value: row.mp, stat: 'mp'),
            (value: row.w, stat: 'w'),
            (value: row.d, stat: 'd'),
            (value: row.l, stat: 'l'),
          ])
            SizedBox(
              key: ValueKey(
                'match-preview-standing-${entry.stat}-${row.teamId}',
              ),
              width: 32,
              child: Text(
                entry.value,
                textAlign: TextAlign.center,
                style: mutedStyle,
              ),
            ),
        ],
      ),
    );
  }
}
