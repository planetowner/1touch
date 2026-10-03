// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:flutter/rendering.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart'
    as fixture_providers;
import 'package:onetouch/data/fixtures/fixture_team_resolver.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team_overview.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/features/match_info/live_match_motion.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class MatchesTab extends StatefulWidget {
  final TeamOverview? team;
  final FixtureRepository? fixtureRepository;
  final VoidCallback? onTopOverscroll;
  final int refreshRequestId;

  const MatchesTab({
    super.key,
    required this.team,
    this.fixtureRepository,
    this.onTopOverscroll,
    this.refreshRequestId = 0,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  // 공유 미리보기에서 디자이너가 확정한 높이와 알파 값을 사용해요.
  static const _topFadeHeight = 40.0;
  static const _topFadeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0x40000000),
      Color(0x80000000),
      Color(0xCC000000),
      Color(0xFF000000),
      Color(0xFF000000),
    ],
    stops: [0, 0.20, 0.45, 0.70, 0.82, 0.92, 1],
  );

  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: false);
  final GlobalKey _entrySliverKey = GlobalKey();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  final GlobalKey _noLiveBoundarySliverKey = GlobalKey();
  final GlobalKey _liveSectionKey = GlobalKey();
  final GlobalKey _pastSectionKey = GlobalKey();
  final Map<_MatchSection, double> _sectionOffsets = {};

  int _visibleHeaderCount = 1;
  bool _hasEarlierMatches = false;
  double _trailingScrollExtent = 24;
  bool _isLoading = true;
  bool _isLiveVerifying = false;
  Object? _loadError;
  int _requestId = 0;

  List<Fixture> pastMatches = const [];
  List<Fixture> liveMatches = const [];
  List<Fixture> upcomingMatches = const [];
  List<Fixture>? _displayedPastPage;
  List<Fixture>? _displayedLivePage;
  List<Fixture>? _displayedUpcomingPage;

  FixtureRepository get _fixtureRepository =>
      widget.fixtureRepository ?? fixture_providers.fixtureDetailRepository;

  FixtureRepository _repositoryFor(MatchesTab configuration) =>
      configuration.fixtureRepository ??
      fixture_providers.fixtureDetailRepository;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncHeaderStack);
    _fixtureRepository.cachedTeamMatches.addListener(_handleCachedMatches);
    _applyCachedMatches();
    unawaited(_loadFixtures());
  }

  void _handleCachedMatches() {
    if (_applyCachedMatches()) setState(() {});
  }

  bool _applyCachedMatches() {
    final teamId = widget.team?.id;
    if (teamId == null) return false;
    final repository = _fixtureRepository;
    final past = repository.cachedForTeamMatches(
      teamId,
      status: FixtureStatus.past,
      limit: 200,
    );
    final live = repository.cachedForTeamMatches(
      teamId,
      status: FixtureStatus.live,
      limit: 200,
    );
    final upcoming = repository.cachedForTeamMatches(
      teamId,
      status: FixtureStatus.upcoming,
      limit: 200,
    );
    if (past == null && live == null && upcoming == null) return false;
    final nextPast = past == null
        ? pastMatches
        : _sortFixturesByKickoff(past, nullsFirst: true);
    final nextLive = live == null ? liveMatches : _sortFixturesByKickoff(live);
    final nextUpcoming =
        upcoming == null ? upcomingMatches : _sortFixturesByKickoff(upcoming);
    if (identical(past, _displayedPastPage) &&
        identical(live, _displayedLivePage) &&
        identical(upcoming, _displayedUpcomingPage)) {
      return false;
    }
    _displayedPastPage = past;
    if (live != null && !identical(live, _displayedLivePage)) {
      _isLiveVerifying = true;
    }
    _displayedLivePage = live;
    _displayedUpcomingPage = upcoming;
    pastMatches = nextPast;
    liveMatches = nextLive;
    upcomingMatches = nextUpcoming;
    if (nextPast.isNotEmpty ||
        nextLive.isNotEmpty ||
        nextUpcoming.isNotEmpty ||
        (past != null && live != null && upcoming != null)) {
      _isLoading = false;
    }
    _loadError = null;
    _schedulePostLoadLayout();
    return true;
  }

  @override
  void dispose() {
    _fixtureRepository.cachedTeamMatches.removeListener(_handleCachedMatches);
    _scrollController
      ..removeListener(_syncHeaderStack)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldRepository = _repositoryFor(oldWidget);
    final repositoryChanged = !identical(oldRepository, _fixtureRepository);
    if (repositoryChanged) {
      oldRepository.cachedTeamMatches.removeListener(_handleCachedMatches);
      _fixtureRepository.cachedTeamMatches.addListener(_handleCachedMatches);
    }
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so reload instead of only
    // loading once in initState.
    if (widget.team?.id != oldWidget.team?.id || repositoryChanged) {
      setState(() {
        _resetForLoad();
        _applyCachedMatches();
      });
      unawaited(_loadFixtures());
    } else if (widget.refreshRequestId != oldWidget.refreshRequestId) {
      unawaited(_loadFixtures(forceRefresh: true));
    }
  }

  Future<void> _loadFixtures({bool forceRefresh = false}) async {
    final requestId = ++_requestId;
    final teamId = widget.team?.id;
    if (teamId == null) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final repository = _fixtureRepository;
      final load =
          forceRefresh ? repository.refreshForTeam : repository.loadForTeam;
      Future<List<Fixture>> loadLive() async {
        var live = await load(
          teamId,
          status: FixtureStatus.live,
          limit: 200,
        );
        if (!forceRefresh &&
            repository.isRefreshingForTeam(
              teamId,
              status: FixtureStatus.live,
              limit: 200,
            )) {
          live = await repository.refreshForTeam(
            teamId,
            status: FixtureStatus.live,
            limit: 200,
          );
        }
        return live;
      }

      final results = await Future.wait([
        load(
          teamId,
          status: FixtureStatus.past,
          limit: 200,
        ),
        loadLive(),
        load(
          teamId,
          status: FixtureStatus.upcoming,
          limit: 200,
        ),
      ]);
      if (!mounted || requestId != _requestId || teamId != widget.team?.id) {
        return;
      }

      setState(() {
        pastMatches = _sortFixturesByKickoff(results[0], nullsFirst: true);
        liveMatches = _sortFixturesByKickoff(results[1]);
        upcomingMatches = _sortFixturesByKickoff(results[2]);
        final centerNoLiveBoundary = liveMatches.isEmpty &&
            pastMatches.isNotEmpty &&
            upcomingMatches.isNotEmpty;
        _visibleHeaderCount = centerNoLiveBoundary ? 1 : _entrySectionIndex + 1;
        _hasEarlierMatches = centerNoLiveBoundary;
        _isLoading = false;
        _isLiveVerifying = false;
        _loadError = null;
      });
      _schedulePostLoadLayout();
    } on Object catch (error) {
      if (!mounted || requestId != _requestId || teamId != widget.team?.id) {
        return;
      }
      setState(() {
        _isLoading = false;
        if (_displayedPastPage == null &&
            _displayedLivePage == null &&
            _displayedUpcomingPage == null &&
            pastMatches.isEmpty &&
            liveMatches.isEmpty &&
            upcomingMatches.isEmpty) {
          _loadError = error;
        }
      });
    }
  }

  void _retryLoad() {
    setState(_resetForLoad);
    unawaited(_loadFixtures());
  }

  void _resetForLoad() {
    _displayedPastPage = null;
    _displayedLivePage = null;
    _displayedUpcomingPage = null;
    pastMatches = const [];
    liveMatches = const [];
    upcomingMatches = const [];
    _isLoading = true;
    _isLiveVerifying = false;
    _loadError = null;
    _sectionOffsets.clear();
    _visibleHeaderCount = 1;
    _hasEarlierMatches = false;
    _trailingScrollExtent = 24;
  }

  void _schedulePostLoadLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderStack();
    });
  }

  void _syncHeaderStack() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final sections = _sections;
    for (final section in sections) {
      final renderObject = section.key.currentContext?.findRenderObject();
      if (renderObject == null || !renderObject.attached) continue;
      final viewport = RenderAbstractViewport.of(renderObject);
      _sectionOffsets[section.type] =
          viewport.getOffsetToReveal(renderObject, 0).offset;
    }

    var nextHeaderCount = sections.isEmpty ? 0 : 1;
    for (var index = sections.length - 1; index > 0; index--) {
      final offset = _sectionOffsets[sections[index].type];
      if (offset != null && _scrollController.offset >= offset - 0.5) {
        nextHeaderCount = index + 1;
        break;
      }
    }

    var nextTrailingScrollExtent = _trailingScrollExtent;
    if (sections.isNotEmpty) {
      final lastOffset = _sectionOffsets[sections.last.type];
      final missingExtent = lastOffset == null
          ? 0.0
          : lastOffset - _scrollController.position.maxScrollExtent;
      if (missingExtent > 0.5) {
        nextTrailingScrollExtent += missingExtent + 1;
      }
    }

    final headerCountDelta = nextHeaderCount - _visibleHeaderCount;
    final hasEarlierMatches = _scrollController.offset >
        _scrollController.position.minScrollExtent + 0.5;
    final earlierMatchesChanged = hasEarlierMatches != _hasEarlierMatches;
    final trailingExtentChanged =
        nextTrailingScrollExtent != _trailingScrollExtent;
    if (headerCountDelta != 0 ||
        earlierMatchesChanged ||
        trailingExtentChanged) {
      setState(() {
        _visibleHeaderCount = nextHeaderCount;
        _hasEarlierMatches = hasEarlierMatches;
        _trailingScrollExtent = nextTrailingScrollExtent;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _syncHeaderStack();
      });
    }
  }

  List<_MatchSectionData> get _sections => [
        if (pastMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.past,
            title: tr(context, 'PAST'),
            matches: pastMatches,
            key: _pastSectionKey,
          ),
        if (liveMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.live,
            title: tr(context, 'LIVE'),
            matches: liveMatches,
            key: _liveSectionKey,
          ),
        if (upcomingMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.upcoming,
            title: tr(context, 'UPCOMING'),
            matches: upcomingMatches,
            key: _upcomingSectionKey,
          ),
      ];

  _MatchSection get _entrySection => liveMatches.isNotEmpty
      ? _MatchSection.live
      : upcomingMatches.isNotEmpty
          ? _MatchSection.upcoming
          : _MatchSection.past;

  int get _entrySectionIndex =>
      _sections.indexWhere((section) => section.type == _entrySection);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: FootballLoadingIndicator(
          key: ValueKey('matches-loading'),
        ),
      );
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(context, 'Unable to load matches'),
              style: Body1.style,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              key: const ValueKey('matches-retry'),
              onPressed: _retryLoad,
              child: Text(tr(context, 'Retry')),
            ),
          ],
        ),
      );
    }

    final sections = _sections;
    if (sections.isEmpty) {
      return Center(
        child: Text(
          tr(context, 'No matches available'),
          key: const ValueKey('matches-empty'),
          style: Body1.style,
        ),
      );
    }
    final visibleHeaderCount = _visibleHeaderCount.clamp(0, sections.length);
    final showTopFade = _hasEarlierMatches;
    final entrySection = _entrySection;
    final entrySectionIndex = _entrySectionIndex;
    final entryPastLeadingCount =
        entrySection == _MatchSection.past ? pastMatches.length - 1 : 0;
    final centerNoLiveBoundary = liveMatches.isEmpty &&
        pastMatches.isNotEmpty &&
        upcomingMatches.isNotEmpty;

    return Column(
      key: const ValueKey('matches-tab-layout'),
      children: [
        if (_isLiveVerifying && liveMatches.isNotEmpty)
          const LinearProgressIndicator(
            key: ValueKey('matches-live-verifying'),
            minHeight: 2,
          ),
        Column(
          key: const ValueKey('matches-header-stack'),
          children: [
            const SizedBox(height: 8),
            SizedBox(
              key: ValueKey('matches-${sections.first.type.name}-header'),
              height: _MatchSectionHeader.sectionHeight,
              child: _MatchSectionHeader(
                title: sections.first.title,
                live: sections.first.type == _MatchSection.live,
              ),
            ),
            for (var index = 1; index < sections.length; index++)
              _AnimatedStickyHeaderSlot(
                key: ValueKey(
                  'matches-${sections[index].type.name}-header-transition',
                ),
                visible: index < visibleHeaderCount,
                section: sections[index],
              ),
            const SizedBox(height: _MatchSectionHeader.cardSpacing),
          ],
        ),
        Expanded(
          // 그림자까지 같은 마스크로 지우고, 페이드가 꺼져도 스크롤 트리는 유지해요.
          child: ShaderMask(
            key: const ValueKey('matches-top-fade'),
            blendMode: showTopFade ? BlendMode.dstIn : BlendMode.dst,
            shaderCallback: (bounds) => _topFadeGradient.createShader(
              Rect.fromLTWH(0, 0, bounds.width, _topFadeHeight),
            ),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is OverscrollNotification &&
                    notification.overscroll < 0 &&
                    notification.metrics.pixels <=
                        notification.metrics.minScrollExtent + 0.5) {
                  widget.onTopOverscroll?.call();
                }
                return false;
              },
              child: CustomScrollView(
                key: const ValueKey('matches-scroll'),
                controller: _scrollController,
                // 라이브가 없으면 지난 경기와 예정 경기의 경계에서 바로 시작해요.
                center: centerNoLiveBoundary
                    ? _noLiveBoundarySliverKey
                    : _entrySliverKey,
                anchor: centerNoLiveBoundary ? 0.5 : 0.0,
                slivers: [
                  for (var index = 0; index < sections.length; index++) ...[
                    // 카드 하단 8px에 16px을 더해 마지막 카드와 divider를 24px 띄워요.
                    if (index > 0)
                      SliverToBoxAdapter(
                        child: const SizedBox(height: 16),
                      ),
                    if (index > 0)
                      SliverToBoxAdapter(
                        key: centerNoLiveBoundary &&
                                sections[index].type == _MatchSection.upcoming
                            ? _noLiveBoundarySliverKey
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            key: ValueKey(
                                'matches-${sections[index].type.name}-divider'),
                            height: 1,
                            color: index < visibleHeaderCount
                                ? Colors.transparent
                                : Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppPalette.lightGrey
                                    : AppColors.of(context).divider,
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        key: sections[index].key,
                        height: index == 0
                            ? 0
                            : _MatchSectionHeader.sectionHeight +
                                _MatchSectionHeader.cardSpacing,
                        child: index == 0 || index < visibleHeaderCount
                            ? const SizedBox.expand()
                            : Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  height: _MatchSectionHeader.sectionHeight,
                                  child: _MatchSectionHeader(
                                    key: ValueKey(
                                      'matches-inline-${sections[index].type.name}-header',
                                    ),
                                    title: sections[index].title,
                                    live: sections[index].type ==
                                        _MatchSection.live,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (index == entrySectionIndex && entryPastLeadingCount > 0)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, matchIndex) => buildMatchCard(
                            sections[index].matches[
                                entryPastLeadingCount - 1 - matchIndex],
                          ),
                          childCount: entryPastLeadingCount,
                        ),
                      ),
                    SliverList(
                      key: sections[index].type == entrySection
                          ? _entrySliverKey
                          : null,
                      delegate: SliverChildBuilderDelegate(
                        (_, matchIndex) {
                          final matches = sections[index].matches;
                          // Slivers above `center` grow upward. Feed them
                          // newest-first so the painted list reads oldest-first.
                          final fixtureIndex = index < entrySectionIndex
                              ? matches.length - 1 - matchIndex
                              : matchIndex +
                                  (index == entrySectionIndex
                                      ? entryPastLeadingCount
                                      : 0);
                          return buildMatchCard(matches[fixtureIndex]);
                        },
                        childCount: sections[index].matches.length -
                            (index == entrySectionIndex
                                ? entryPastLeadingCount
                                : 0),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: _trailingScrollExtent),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildMatchCard(Fixture fixture) {
    final appColors = AppColors.of(context);
    final cardBackground = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : AppPalette.lightGreyBox;
    final isUpcoming = fixture.status == FixtureStatus.upcoming;
    final home = fixtureHomeTeam(fixture, teamRepository);
    final away = fixtureAwayTeam(fixture, teamRepository);
    final leagueName = competitionNameLabel(
        context,
        fixture.competitionId,
        competitionRepository.findById(fixture.competitionId)?.name ??
            'Unknown');
    final roundLabel =
        fixtureRoundLabel(fixture, locale: Localizations.localeOf(context));
    final competitionAndRound = fixtureCompetitionLabel(context, fixture) ??
        (roundLabel != null ? '$leagueName • $roundLabel' : leagueName);

    return GestureDetector(
      onTap: () => GoRouter.of(context).push(
        '/match/${fixture.fixtureId}?status=${fixture.status.name}',
        extra: fixture,
      ),
      child: Container(
        key: ValueKey('team-fixture-card-${fixture.fixtureId}'),
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: appCardShadows(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.network(
                        home.imagePath ?? '',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            teamLogoFallback(home.teamId, size: 32),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          home.shortCode ??
                              teamNameLabel(context, home.teamId, home.name),
                          style: Heading5.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isUpcoming)
                  SizedBox(
                    width: 96,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: FixtureDateTime(
                        label: fixtureDateLabel(fixture.kickoff,
                            locale: Localizations.localeOf(context)),
                        overflow: TextOverflow.visible,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    width: 96,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        children: [
                          scoreboard(
                            fixture.homeScore ?? 0,
                            isDimmed: (fixture.homeScore ?? 0) <
                                (fixture.awayScore ?? 0),
                          ),
                          const SizedBox(width: 8),
                          scoreboard(
                            fixture.awayScore ?? 0,
                            isDimmed: (fixture.awayScore ?? 0) <
                                (fixture.homeScore ?? 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          away.shortCode ??
                              teamNameLabel(context, away.teamId, away.name),
                          style: Heading5.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.network(
                        away.imagePath ?? '',
                        width: 32,
                        height: 32,
                        errorBuilder: (_, __, ___) =>
                            teamLogoFallback(away.teamId, size: 32),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isUpcoming) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 24, height: 1, color: appColors.divider),
                ],
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 8),
            SizedBox(
              key: ValueKey('match-competition-round-${fixture.fixtureId}'),
              width: double.infinity,
              child: Text(
                competitionAndRound,
                style: Body2.style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget scoreboard(int score, {required bool isDimmed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppPalette.black : AppPalette.lightModeDarkGrey,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        score.toString(),
        textAlign: TextAlign.center,
        style: Heading3.latinStyle.copyWith(
          color: !isDark && isDimmed
              ? foreground.withValues(alpha: 0.5)
              : foreground,
        ),
      ),
    );
    return isDark && isDimmed ? Opacity(opacity: 0.5, child: box) : box;
  }
}

List<Fixture> _sortFixturesByKickoff(
  List<Fixture> fixtures, {
  bool nullsFirst = false,
}) {
  final sorted = List<Fixture>.of(fixtures)
    ..sort((left, right) {
      final leftKickoff = left.kickoff;
      final rightKickoff = right.kickoff;
      if (leftKickoff == null && rightKickoff != null) {
        return nullsFirst ? -1 : 1;
      }
      if (leftKickoff != null && rightKickoff == null) {
        return nullsFirst ? 1 : -1;
      }
      final byKickoff =
          leftKickoff == null ? 0 : leftKickoff.compareTo(rightKickoff!);
      return byKickoff != 0
          ? byKickoff
          : left.fixtureId.compareTo(right.fixtureId);
    });
  return List.unmodifiable(sorted);
}

class _MatchSectionHeader extends StatelessWidget {
  final String title;
  final bool live;

  const _MatchSectionHeader(
      {super.key, required this.title, this.live = false});

  static const double sectionHeight = 34;
  static const double cardSpacing = 8;
  static const double stickySpacing = 8;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (live) ...[
                  LivePulseDot(color: Body2_b.style.color),
                  const SizedBox(width: 4),
                ],
                Text(title, style: Body2_b.style.copyWith(height: 18 / 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedStickyHeaderSlot extends StatelessWidget {
  final bool visible;
  final _MatchSectionData section;

  const _AnimatedStickyHeaderSlot({
    super.key,
    required this.visible,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.fastOutSlowIn,
      switchOutCurve: Curves.fastOutSlowIn,
      transitionBuilder: (child, animation) {
        final opacity = Tween(begin: 0.72, end: 1.0).animate(animation);
        final offset = Tween(
          begin: const Offset(0, 4 / _MatchSectionHeader.sectionHeight),
          end: Offset.zero,
        ).animate(animation);
        return SizeTransition(
          sizeFactor: animation,
          alignment: Alignment.topCenter,
          child: FadeTransition(
            opacity: opacity,
            child: SlideTransition(position: offset, child: child),
          ),
        );
      },
      child: visible
          ? SizedBox(
              key: ValueKey('matches-${section.type.name}-header'),
              height: _MatchSectionHeader.sectionHeight +
                  _MatchSectionHeader.stickySpacing,
              child: Padding(
                padding: const EdgeInsets.only(
                    top: _MatchSectionHeader.stickySpacing),
                child: _MatchSectionHeader(
                  title: section.title,
                  live: section.type == _MatchSection.live,
                ),
              ),
            )
          : SizedBox(
              key: ValueKey('matches-${section.type.name}-header-hidden'),
            ),
    );
  }
}

enum _MatchSection { past, live, upcoming }

class _MatchSectionData {
  final _MatchSection type;
  final String title;
  final List<Fixture> matches;
  final GlobalKey key;

  const _MatchSectionData({
    required this.type,
    required this.title,
    required this.matches,
    required this.key,
  });
}
