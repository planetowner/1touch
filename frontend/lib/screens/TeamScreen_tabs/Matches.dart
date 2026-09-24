import 'dart:async';

import 'package:flutter/material.dart';
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
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';
import 'package:onetouch/l10n/fixture_labels.dart';

class MatchesTab extends StatefulWidget {
  final Map<String, dynamic>? team;
  final FixtureRepository? fixtureRepository;

  const MatchesTab({
    super.key,
    required this.team,
    this.fixtureRepository,
  });

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final ScrollController _scrollController =
      ScrollController(keepScrollOffset: false);
  final GlobalKey _entrySliverKey = GlobalKey();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  final GlobalKey _liveSectionKey = GlobalKey();
  final GlobalKey _pastSectionKey = GlobalKey();
  final Map<_MatchSection, double> _sectionOffsets = {};

  int _visibleHeaderCount = 1;
  bool _applyingHeaderCorrection = false;
  double _trailingScrollExtent = 24;
  bool _isLoading = true;
  Object? _loadError;
  int _requestId = 0;

  List<Fixture> pastMatches = const [];
  List<Fixture> liveMatches = const [];
  List<Fixture> upcomingMatches = const [];

  FixtureRepository get _fixtureRepository =>
      widget.fixtureRepository ?? fixture_providers.fixtureDetailRepository;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncHeaderStack);
    unawaited(_loadFixtures());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncHeaderStack)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so reload instead of only
    // loading once in initState.
    if (widget.team?['id'] != oldWidget.team?['id'] ||
        widget.fixtureRepository != oldWidget.fixtureRepository) {
      setState(() {
        _resetForLoad();
      });
      unawaited(_loadFixtures());
    }
  }

  Future<void> _loadFixtures() async {
    final requestId = ++_requestId;
    final teamId = widget.team?['id'] as int?;
    if (teamId == null) {
      if (!mounted || requestId != _requestId) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final repository = _fixtureRepository;
      final results = await Future.wait([
        repository.loadForTeam(
          teamId,
          status: FixtureStatus.past,
          limit: 200,
        ),
        repository.loadForTeam(
          teamId,
          status: FixtureStatus.live,
          limit: 200,
        ),
        repository.loadForTeam(
          teamId,
          status: FixtureStatus.upcoming,
          limit: 200,
        ),
      ]);
      if (!mounted || requestId != _requestId || teamId != widget.team?['id']) {
        return;
      }

      setState(() {
        // 화면은 미래에서 과거로 이어져요. 가까운 일정부터 오는 예정 경기만 뒤집어요.
        pastMatches = results[0];
        liveMatches = results[1];
        upcomingMatches = results[2].reversed.toList(growable: false);
        _isLoading = false;
        _loadError = null;
      });
      _schedulePostLoadLayout();
    } on Object catch (error) {
      if (!mounted || requestId != _requestId || teamId != widget.team?['id']) {
        return;
      }
      setState(() {
        pastMatches = const [];
        liveMatches = const [];
        upcomingMatches = const [];
        _isLoading = false;
        _loadError = error;
      });
    }
  }

  void _retryLoad() {
    setState(_resetForLoad);
    unawaited(_loadFixtures());
  }

  void _resetForLoad() {
    pastMatches = const [];
    liveMatches = const [];
    upcomingMatches = const [];
    _isLoading = true;
    _loadError = null;
    _sectionOffsets.clear();
    _visibleHeaderCount = 1;
    _trailingScrollExtent = 24;
  }

  void _schedulePostLoadLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderStack();
    });
  }

  void _syncHeaderStack() {
    if (!mounted ||
        _applyingHeaderCorrection ||
        !_scrollController.hasClients) {
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
    final trailingExtentChanged =
        nextTrailingScrollExtent != _trailingScrollExtent;
    if (headerCountDelta != 0 || trailingExtentChanged) {
      final scrollOffsetBeforeLayout = _scrollController.offset;
      setState(() {
        _visibleHeaderCount = nextHeaderCount;
        _trailingScrollExtent = nextTrailingScrollExtent;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;

        if (headerCountDelta != 0) {
          final correction =
              headerCountDelta * _MatchSectionHeader.sectionHeight;
          final correctedOffset = (scrollOffsetBeforeLayout + correction).clamp(
              _scrollController.position.minScrollExtent,
              _scrollController.position.maxScrollExtent);
          _applyingHeaderCorrection = true;
          _scrollController.jumpTo(correctedOffset);
          _applyingHeaderCorrection = false;
        }
        _syncHeaderStack();
      });
    }
  }

  List<_MatchSectionData> get _sections => [
        if (upcomingMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.upcoming,
            title: tr(context, 'UPCOMING'),
            matches: upcomingMatches,
            key: _upcomingSectionKey,
          ),
        if (liveMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.live,
            title: tr(context, '• LIVE'),
            matches: liveMatches,
            key: _liveSectionKey,
          ),
        if (pastMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.past,
            title: tr(context, 'PAST'),
            matches: pastMatches,
            key: _pastSectionKey,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
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
    final laterUpcomingCount =
        (upcomingMatches.length - 2).clamp(0, upcomingMatches.length);
    final pageBackground = mainPageBackground(context);

    return Column(
      key: const ValueKey('matches-tab-layout'),
      children: [
        Column(
          key: const ValueKey('matches-header-stack'),
          children: [
            const SizedBox(height: 8),
            for (final section in sections.take(visibleHeaderCount))
              SizedBox(
                key: ValueKey('matches-${section.type.name}-header'),
                height: _MatchSectionHeader.sectionHeight,
                child: _MatchSectionHeader(title: section.title),
              ),
          ],
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomScrollView(
                key: const ValueKey('matches-scroll'),
                controller: _scrollController,
                // 가까운 예정 경기 두 개에서 시작하고, 더 먼 일정은 위로 이어 붙여요.
                center: _entrySliverKey,
                slivers: [
                  if (laterUpcomingCount > 0)
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => buildMatchCard(
                          upcomingMatches[laterUpcomingCount - index - 1],
                        ),
                        childCount: laterUpcomingCount,
                      ),
                    ),
                  for (var index = 0; index < sections.length; index++) ...[
                    // 카드 아래 여백 16px에 8px을 더해 섹션 사이에만 선을 놓아요.
                    if (index > 0)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: Container(
                            key: ValueKey(
                                'matches-${sections[index].type.name}-divider'),
                            height: 1,
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppPalette.lightGrey
                                    : AppColors.of(context).divider,
                          ),
                        ),
                      ),
                    if (index > 0)
                      SliverToBoxAdapter(
                        child: SizedBox(
                          key: sections[index].key,
                          height: _MatchSectionHeader.sectionHeight,
                          child: index < visibleHeaderCount
                              ? const SizedBox.expand()
                              : _MatchSectionHeader(
                                  key: ValueKey(
                                    'matches-inline-${sections[index].type.name}-header',
                                  ),
                                  title: sections[index].title,
                                ),
                        ),
                      )
                    else
                      SliverToBoxAdapter(
                        key: _entrySliverKey,
                        child: SizedBox(key: sections[index].key, height: 0),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, matchIndex) => buildMatchCard(
                          sections[index].matches[matchIndex +
                              (sections[index].type == _MatchSection.upcoming
                                  ? laterUpcomingCount
                                  : 0)],
                        ),
                        childCount: sections[index].matches.length -
                            (sections[index].type == _MatchSection.upcoming
                                ? laterUpcomingCount
                                : 0),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: EdgeInsets.only(bottom: _trailingScrollExtent),
                  ),
                ],
              ),
              if (upcomingMatches.length > 1 && visibleHeaderCount == 1)
                Positioned(
                  top: 0,
                  left: 24,
                  right: 24,
                  height: 56,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const ValueKey('matches-top-fade'),
                      decoration: BoxDecoration(
                        // 스크롤 경계부터 가려야 지나가는 카드 위에 밝은 띠가 남지 않아요.
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            pageBackground,
                            pageBackground.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                SizedBox(
                  width: isUpcoming ? 84 : 96,
                  child: isUpcoming
                      ? FixtureDateTime(
                          label: fixtureDateLabel(fixture.kickoff,
                              locale: Localizations.localeOf(context)),
                        )
                      : FittedBox(
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
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: isDimmed ? 0.5 : 1.0,
      child: Material(
        // elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center, // Centers the text
          decoration: BoxDecoration(
            color: colors.onPrimary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(score.toString(),
              textAlign: TextAlign.center,
              style: Heading3.style.copyWith(color: colors.primary)),
        ),
      ),
    );
  }
}

class _MatchSectionHeader extends StatelessWidget {
  final String title;

  const _MatchSectionHeader({super.key, required this.title});

  static const double sectionHeight = 34;

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
            child: Text(title, style: Body2_b.style.copyWith(height: 18 / 14)),
          ),
        ],
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
