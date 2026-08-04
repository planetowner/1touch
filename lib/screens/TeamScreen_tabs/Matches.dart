import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:onetouch/data/competitions/mock/league_catalog.dart';
import 'package:onetouch/data/matches/mock/fixture_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
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
  final GlobalKey _liveSectionKey = GlobalKey();

  List<Fixture> pastMatches = [];
  List<Fixture> liveMatches = [];
  List<Fixture> upcomingMatches = [];

  @override
  void initState() {
    super.initState();
    _loadFixtures();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToLiveSection();
    });
  }

  @override
  void didUpdateWidget(MatchesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This tab's State is reused across team switches (the Team-tab branch
    // stays alive in the bottom-nav shell), so reload instead of only
    // loading once in initState.
    if (widget.team?['id'] != oldWidget.team?['id']) {
      setState(_loadFixtures);
    }
  }

  void _loadFixtures() {
    final teamId = widget.team?['id'] as int?;
    if (teamId == null) return;

    final all = fixturesByTeam(teamId);
    pastMatches = all.where((f) => f.status == FixtureStatus.past).toList();
    liveMatches = all.where((f) => f.status == FixtureStatus.live).toList();
    upcomingMatches =
        all.where((f) => f.status == FixtureStatus.upcoming).toList();
  }

  void scrollToLiveSection() {
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

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── UPCOMING section ──────────────────────────────────────────
        if (upcomingMatches.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(title: 'UPCOMING'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => buildMatchCard(upcomingMatches[i]),
              childCount: upcomingMatches.length,
            ),
          ),
        ],

        // Invisible marker for scrollToLiveSection() measurement
        SliverToBoxAdapter(
          child: SizedBox(key: _liveSectionKey, height: 0),
        ),

        // ── LIVE section ──────────────────────────────────────────────
        if (liveMatches.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(title: '• LIVE'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => buildMatchCard(liveMatches[i]),
              childCount: liveMatches.length,
            ),
          ),
        ],

        // ── PAST section ──────────────────────────────────────────────
        if (pastMatches.isNotEmpty) ...[
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(title: 'PAST'),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => buildMatchCard(pastMatches[i]),
              childCount: pastMatches.length,
            ),
          ),
        ],

        const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
      ],
    );
  }

  Widget buildMatchCard(Fixture fixture) {
    final appColors = AppColors.of(context);
    final cardBackground = Theme.of(context).brightness == Brightness.dark
        ? AppPalette.lightGrey
        : AppPalette.lightGreyBox;
    final isUpcoming = fixture.status == FixtureStatus.upcoming;
    final home = mockTeamById(fixture.homeTeamId);
    final away = mockTeamById(fixture.awayTeamId);
    final league = mockLeagueById(fixture.leagueId);
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
              '${league.name} • ${fixture.roundName}',
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

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;

  _StickyHeaderDelegate({required this.title});

  static const double _kHeight = 50; // 16 top + text + ~16 gap + divider

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final appColors = AppColors.of(context);
    return Container(
      color: mainPageBackground(context),
      // Solid background so list items hide cleanly behind the pinned header.
      // The AppBar's own gradient background bleeds down behind/over this
      // as needed — no gradient added inside the header itself.
      // color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: Body2_b.style),
          ),
          const Spacer(), // ~16px gap between text and divider
          Container(height: 0.7, color: appColors.divider),
        ],
      ),
    );
  }

  @override
  double get maxExtent => _kHeight;

  @override
  double get minExtent => _kHeight;

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.title != title;
}
