import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/fixture.dart';
import '../models/league.dart';
import 'TeamScreen_tabs/index.dart';
import '../data/teamdata.dart';


class TeamScreen extends StatefulWidget {
  final int teamId;

  TeamScreen({super.key, required this.teamId});

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

  // Future<void> fetchTeamData() async {
  //   final url =
  //       'https://3e6a1be77d44.ngrok-free.app/api/teams/${widget.teamId}/overview';
  //   try {
  //     final response = await http.get(Uri.parse(url));
  //     if (response.statusCode == 200) {
  //       final jsonMap = json.decode(response.body) as Map<String, dynamic>;
  //       final parsed = Team.fromJson(jsonMap); // ✅ parse API object
  //       final int leagueId = parsed.leagueId;
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

    // 🔁 Toggle which source to use
    loadMockData();     // local fake JSON
    // fetchTeamData(); // real API
  }

  void loadMockData() {
    // Look up team from mock data
    final mockTeam = mockTeams.where((t) => t.teamId == widget.teamId).firstOrNull;
    if (mockTeam == null) {
      setState(() => isLoading = false);
      return;
    }
    _teamColor = Color(mockTeam.primaryColor);

    final fixtures = fixturesByTeam(widget.teamId);
    final nextMatch = fixtures.where((f) => f.status == FixtureStatus.upcoming).firstOrNull;
    final lastMatch = fixtures.where((f) => f.status == FixtureStatus.past).lastOrNull;

    // Get league from fixtures
    final leagueId = nextMatch?.leagueId ?? lastMatch?.leagueId;
    final standing = leagueId != null ? standingByTeam(leagueId, widget.teamId) : null;
    final leagueName = leagueId != null ? (leagueNames[leagueId] ?? 'League') : 'League';
    final position = standing != null
        ? '$leagueName ${ordinal(standing.position)}'
        : leagueName;

    // Build Team view model
    final teamObj = Team(
      id: mockTeam.teamId,
      name: mockTeam.name,
      shortName: mockTeam.shortCode ?? '',
      imagePath: mockTeam.imagePath ?? '',
      standing: standing != null ? {
        'position': standing.position,
        'points': standing.points,
        'matches_played': standing.matchesPlayed,
        'won': standing.won,
        'draw': standing.draw,
        'lost': standing.lost,
        'goals_for': standing.goalsFor,
        'goals_against': standing.goalsAgainst,
        'goal_diff': standing.goalDiff,
      } : null,
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
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (team == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("Team Not Found")),
      );
    }

    final double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0, left: 0, right: 0, height: 550,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [_teamColor, _teamColor.withAlpha(0)],
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
                backgroundColor: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                pinned: false,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [_teamColor, _teamColor.withAlpha(0)],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: Row(
                    children: [
                      Image.network(
                        team?['logo'],
                        height: 52, width: 53, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'TeamLogos/Barcelona.png', height: 52, width: 53,
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
                              style: Heading4.style,
                              maxLines: 1, // Ensure it stays on one line
                              overflow: TextOverflow.ellipsis, // Now this will work correctly
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(team!['position'] as String, style: Body2.style),
                                const Icon(Icons.arrow_drop_up, size: 16, color: Colors.green),
                                Text(
                                  team!['rankChange'] != 0 ? ' ${team!['rankChange']}' : '',
                                  style: Eyebrow.style,
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
                          onPressed: () => context.push('/profile'),
                          icon: const Icon(Icons.account_circle_outlined, size: 32),
                        ),
                        IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search, size: 32),
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
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.white,
                    labelStyle: Heading5.style,
                    unselectedLabelStyle: Heading5.style,
                    indicatorSize: TabBarIndicatorSize.label,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.only(left: 8, top: 24),
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: Colors.white, width: 1.2),
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
  double get minExtent => _tabBar.preferredSize.height + 8; // a bit of top padding

  @override
  double get maxExtent => _tabBar.preferredSize.height + 8;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      // color: Colors.black, // solid bg so it looks clean when pinned
      alignment: Alignment.centerLeft,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}