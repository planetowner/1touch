import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/features/helper.dart';

class MatchesTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const MatchesTab({super.key, required this.team});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _upcomingSectionKey = GlobalKey();
  final GlobalKey _liveSectionKey = GlobalKey();
  final GlobalKey _pastSectionKey = GlobalKey();
  final Map<_MatchSection, double> _sectionOffsets = {};

  int _visibleHeaderCount = 1;
  bool _headerSyncScheduled = false;
  bool _applyingHeaderCorrection = false;
  double _trailingScrollExtent = 24;

  List<Fixture> pastMatches = [];
  List<Fixture> liveMatches = [];
  List<Fixture> upcomingMatches = [];

  @override
  void initState() {
    super.initState();
    _loadFixtures();
    _scrollController.addListener(_scheduleHeaderSync);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToLiveSection();
      _scheduleHeaderSync();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleHeaderSync)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so reload instead of only
    // loading once in initState.
    if (widget.team?['id'] != oldWidget.team?['id']) {
      setState(() {
        _loadFixtures();
        _sectionOffsets.clear();
        _visibleHeaderCount = 1;
        _trailingScrollExtent = 24;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        scrollToLiveSection();
        _scheduleHeaderSync();
      });
    }
  }

  void _loadFixtures() {
    final teamId = widget.team?['id'] as int?;
    if (teamId == null) return;

    pastMatches = fixtureRepository.forTeam(
      teamId,
      status: FixtureStatus.past,
    );
    liveMatches = fixtureRepository.forTeam(
      teamId,
      status: FixtureStatus.live,
    );
    upcomingMatches = fixtureRepository.forTeam(
      teamId,
      status: FixtureStatus.upcoming,
    );
  }

  void scrollToLiveSection() {
    if (liveMatches.isEmpty) return;

    final box =
        _liveSectionKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final offset = box.localToGlobal(Offset.zero).dy;
    final screenHeight = MediaQuery.of(context).size.height;
    final scrollOffset = _scrollController.offset +
        offset -
        (screenHeight / 2) +
        (box.size.height / 2);
    _scrollController.jumpTo(
      scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
    );
  }

  void _scheduleHeaderSync() {
    if (_headerSyncScheduled || _applyingHeaderCorrection || !mounted) return;
    _headerSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerSyncScheduled = false;
      _syncHeaderStack();
    });
  }

  void _syncHeaderStack() {
    if (!mounted || !_scrollController.hasClients) return;

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
          final correctedOffset = (scrollOffsetBeforeLayout + correction)
              .clamp(0.0, _scrollController.position.maxScrollExtent);
          _applyingHeaderCorrection = true;
          _scrollController.jumpTo(correctedOffset);
          _applyingHeaderCorrection = false;
        }
        _scheduleHeaderSync();
      });
    }
  }

  List<_MatchSectionData> get _sections => [
        if (upcomingMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.upcoming,
            title: 'UPCOMING',
            matches: upcomingMatches,
            key: _upcomingSectionKey,
          ),
        if (liveMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.live,
            title: '• LIVE',
            matches: liveMatches,
            key: _liveSectionKey,
          ),
        if (pastMatches.isNotEmpty)
          _MatchSectionData(
            type: _MatchSection.past,
            title: 'PAST',
            matches: pastMatches,
            key: _pastSectionKey,
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final sections = _sections;
    final visibleHeaderCount = _visibleHeaderCount.clamp(0, sections.length);

    return Column(
      key: const ValueKey('matches-tab-layout'),
      children: [
        Column(
          key: const ValueKey('matches-header-stack'),
          children: [
            for (final section in sections.take(visibleHeaderCount))
              SizedBox(
                key: ValueKey('matches-${section.type.name}-header'),
                height: _MatchSectionHeader.sectionHeight,
                child: _StackedMatchSectionHeader(
                  title: section.title,
                  animate: section.type != _MatchSection.upcoming,
                ),
              ),
          ],
        ),
        Expanded(
          child: CustomScrollView(
            key: const ValueKey('matches-scroll'),
            controller: _scrollController,
            slivers: [
              for (var index = 0; index < sections.length; index++) ...[
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
                    child: SizedBox(key: sections[index].key, height: 0),
                  ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, matchIndex) =>
                        buildMatchCard(sections[index].matches[matchIndex]),
                    childCount: sections[index].matches.length,
                  ),
                ),
              ],
              SliverPadding(
                padding: EdgeInsets.only(bottom: _trailingScrollExtent),
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
    final home = teamRepository.findByIdOrUnknown(fixture.homeTeamId);
    final away = teamRepository.findByIdOrUnknown(fixture.awayTeamId);
    final leagueName =
        competitionRepository.findById(fixture.competitionId)?.name ??
            'Unknown';
    final dt = DateTime.parse(fixture.startingAt).toLocal();

    return GestureDetector(
      onTap: () => GoRouter.of(context)
          .push('/match/${fixture.fixtureId}?status=${fixture.status.name}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(14),
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
                          home.shortCode ?? home.name,
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
                      ? Text(
                          DateFormat('E, MMM d\nh:mm a').format(dt),
                          style: Body2.style,
                          textAlign: TextAlign.center,
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
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(":", style: Heading5.style),
                              ),
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
                          away.shortCode ?? away.name,
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
            Text(
              '$leagueName • ${fixture.roundName}',
              style: Body2.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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

  static const double sectionHeight = 50;

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
            child: Text(title, style: Body2_b.style),
          ),
          const Spacer(),
          Container(height: 0.7, color: AppColors.of(context).divider),
        ],
      ),
    );
  }
}

class _StackedMatchSectionHeader extends StatefulWidget {
  final String title;
  final bool animate;

  const _StackedMatchSectionHeader({
    required this.title,
    required this.animate,
  });

  @override
  State<_StackedMatchSectionHeader> createState() =>
      _StackedMatchSectionHeaderState();
}

class _StackedMatchSectionHeaderState
    extends State<_StackedMatchSectionHeader> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _visible = !widget.animate;
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      offset: _visible ? Offset.zero : const Offset(0, -0.12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: _MatchSectionHeader(title: widget.title),
      ),
    );
  }
}

enum _MatchSection { upcoming, live, past }

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
