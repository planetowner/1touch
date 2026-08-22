import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/fixtures/fixture_repository_provider.dart';
import 'package:onetouch/data/standings/standing_repository_provider.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart'
    as team_providers;
import 'package:onetouch/features/helper.dart';
import 'TeamScreen_tabs/index.dart';
import '../models/team_overview.dart';

class TeamScreen extends StatefulWidget {
  final int teamId;
  final TeamRepository? teamRepository;

  TeamScreen({
    super.key,
    required this.teamId,
    this.teamRepository,
  });

  @override
  _TeamScreenState createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final TabController _tabController;
  double _scrollOffset = 0.0;

  Map<String, dynamic>? team;
  bool isLoading = true;
  Color _teamColor = const Color(0xFFD82457);

  TeamRepository get _teamRepository =>
      widget.teamRepository ?? team_providers.teamRepository;

  // Future<void> fetchTeamData() async {
  //   final url =
  //       'https://3e6a1be77d44.ngrok-free.app/api/teams/${widget.teamId}/overview';
  //   try {
  //     final response = await http.get(Uri.parse(url));
  //     if (response.statusCode == 200) {
  //       final jsonMap = json.decode(response.body) as Map<String, dynamic>;
  //       final parsed = Team.fromJson(jsonMap); // ✅ parse API object
  //       final int leagueId = parsed.competitionId;
  //       final int? rank = parsed.standing?['rank'] as int?;
  //       final String leagueName = {
  //         8: "Premier League",
  //         82: "La Liga",
  //         301: "Serie A",
  //         384: "Bundesliga",
  //         564: "Ligue 1",
  //       }[leagueId] ?? 'League';
  //       final position = rank != null ? "$leagueName ${ordinal(rank)}" : leagueName;
  //
  //       setState(() {
  //         teams = [parsed]; // ✅ List<Team>
  //         team = {          // ✅ Map<String, dynamic> for your UI
  //           "id": parsed.id,
  //           "name": parsed.name,
  //           "position": position,
  //           "logo": parsed.imagePath, // network URL; we handle below
  //           "rankChange": 0,
  //           "raw": jsonMap,
  //         };
  //         isLoading = false;
  //       });
  //     } else {
  //       print("Failed to load team data: ${response.statusCode}");
  //       setState(() => isLoading = false);
  //     }
  //   } catch (e) {
  //     print("Error: $e");
  //     setState(() => isLoading = false);
  //   }
  // }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: 5, vsync: this); // ✅ add init
    currentUserPreferences.followedTeamIds.addListener(_onFollowingChanged);

    // 🔁 Toggle which source to use
    loadMockData(); // local fake JSON
    // fetchTeamData(); // real API
  }

  void _onFollowingChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleFollowing() async {
    final changed =
        await currentUserPreferences.toggleFollowedTeam(widget.teamId);
    if (!mounted || changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('At least one team must stay followed.')),
    );
  }

  @override
  void didUpdateWidget(TeamScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This screen's State is reused across team switches (the Team-tab
    // branch stays alive in the bottom-nav shell), so reload instead of
    // only loading once in initState — otherwise it keeps showing whichever
    // team was loaded first, forever.
    if (widget.teamId != oldWidget.teamId) {
      loadMockData();
    }
  }

  void loadMockData() {
    final resolvedTeam = _teamRepository.findById(widget.teamId);
    if (resolvedTeam == null) {
      setState(() {
        team = null;
        isLoading = false;
      });
      return;
    }
    _teamColor = Color(resolvedTeam.primaryColor);

    final nextMatch = fixtureRepository.nextForTeam(widget.teamId);
    final lastMatch = fixtureRepository.lastForTeam(widget.teamId);

    // Get league from fixtures
    final leagueId = nextMatch?.competitionId ?? lastMatch?.competitionId;
    final standing = leagueId != null
        ? standingRepository.findForTeam(leagueId, widget.teamId)
        : null;
    final leagueName = leagueId != null
        ? (competitionRepository.findById(leagueId)?.name ?? 'League')
        : 'League';
    final position = standing != null
        ? '$leagueName ${ordinal(standing.position)}'
        : leagueName;

    // Build team view model
    final teamObj = TeamOverview(
      id: resolvedTeam.teamId,
      name: resolvedTeam.name,
      shortName: resolvedTeam.shortCode ?? '',
      imagePath: resolvedTeam.imagePath ?? '',
      standing: standing != null
          ? {
              'position': standing.position,
              'points': standing.points,
              'matches_played': standing.matchesPlayed,
              'won': standing.won,
              'draw': standing.draw,
              'lost': standing.lost,
              'goals_for': standing.goalsFor,
              'goals_against': standing.goalsAgainst,
              'goal_diff': standing.goalDiff,
            }
          : null,
      nextMatch: nextMatch,
      lastMatch: lastMatch,
    );

    setState(() {
      team = {
        'id': teamObj.id,
        'name': teamObj.name,
        'short_code': teamObj.shortName,
        'image_path': teamObj.imagePath,
        'position': position,
        'logo': teamObj.imagePath,
        'rankChange': 0,
        'standing': teamObj.standing,
        'next_match': nextMatch,
        'last_match': lastMatch,
        // Pass raw team object for widgets that need it
        'teamObj': teamObj,
      };
      isLoading = false;
    });
  }

  @override
  void dispose() {
    currentUserPreferences.followedTeamIds.removeListener(_onFollowingChanged);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);

    if (isLoading) {
      return Scaffold(
        backgroundColor: pageBackground,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (team == null) {
      return Scaffold(
        key: const ValueKey('team-not-found'),
        backgroundColor: pageBackground,
        body: const Center(child: Text('Team Not Found')),
      );
    }

    final double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    const appBarForeground = AppPalette.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('team-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_teamColor, pageBackground],
                    stops: const [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Color.lerp(
                  Colors.transparent,
                  pageBackground,
                  opacityFactor,
                ),
                foregroundColor: appBarForeground,
                elevation: 0,
                floating: true,
                snap: true,
                pinned: false,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _teamColor,
                        _teamColor.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/team/${team!['id']}'),
                        child: Image.network(
                          team?['logo'],
                          height: 52,
                          width: 53,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              teamLogoFallback(team!['id'] as int, size: 52),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              // '1. Fußballclub Heidenheim 1846 e.V',
                              team?['name'],
                              style: Heading4.style
                                  .copyWith(color: appBarForeground),
                              maxLines: 1, // Ensure it stays on one line
                              overflow: TextOverflow
                                  .ellipsis, // Now this will work correctly
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  child: Text(
                                    team!['position'] as String,
                                    style: Body2.style
                                        .copyWith(color: appBarForeground),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(Icons.arrow_drop_up,
                                    size: 16, color: Colors.green),
                                Text(
                                  team!['rankChange'] != 0
                                      ? ' ${team!['rankChange']}'
                                      : '',
                                  style: Eyebrow.style
                                      .copyWith(color: appBarForeground),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('team-follow-button'),
                          tooltip: currentUserPreferences.followedTeamIds.value
                                  .contains(widget.teamId)
                              ? 'Unfollow team'
                              : 'Follow team',
                          onPressed: _toggleFollowing,
                          icon: Icon(
                            currentUserPreferences.followedTeamIds.value
                                    .contains(widget.teamId)
                                ? Icons.star
                                : Icons.star_outline,
                            size: 32,
                            color: AppPalette.white,
                          ),
                        ),
                        IconButton(
                          key: const Key('team-search-button'),
                          onPressed: () => context.push('/search'),
                          icon: const Icon(
                            Icons.search,
                            size: 32,
                            color: AppPalette.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliverPersistentHeader(
                pinned: false,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: colors.onSurface,
                    unselectedLabelColor: appColors.mutedForeground,
                    indicatorColor: colors.onSurface,
                    labelStyle: Heading5.style,
                    unselectedLabelStyle: Heading5.style,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.only(left: 8),
                    indicator: UnderlineTabIndicator(
                      borderSide: BorderSide(color: colors.onSurface, width: 2),
                    ),
                    tabs: const [
                      Tab(text: "Overview"),
                      Tab(text: "Matches"),
                      Tab(text: "Standing"),
                      Tab(text: "Squad"),
                      Tab(text: "Analysis"),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(team: team),
                MatchesTab(team: team),
                StandingTab(team: team),
                SquadTab(team: team),
                AnalysisTab(team: team),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent =>
      _tabBar.preferredSize.height + 8; // a bit of top padding

  @override
  double get maxExtent => _tabBar.preferredSize.height + 8;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      // color: Colors.black, // solid bg so it looks clean when pinned
      alignment: Alignment.centerLeft,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
