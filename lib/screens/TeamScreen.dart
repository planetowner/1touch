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
  late final TabController _tabController;
  late final TabBar _tabBar;

  Map<String, dynamic>? team;
  bool isLoading = true;
  Color _teamColor = const Color(0xFFD82457);

  // Measured height of the fixed header (logo/name/tabs) so each tab's
  // scroll view can pad its top by exactly that much and start underneath
  // it instead of being covered by it. Updated once the header lays out.
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 170;

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

    _tabController = TabController(length: 5, vsync: this);
    _tabBar = TabBar(
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
      padding: const EdgeInsets.only(left: 8),
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
    );

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

  void _measureHeader() {
    final renderHeight = _headerKey.currentContext?.size?.height;
    if (renderHeight == null) return;
    if ((renderHeight - _headerHeight).abs() > 0.5) {
      setState(() => _headerHeight = renderHeight);
    }
  }

  @override
  void dispose() {
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureHeader());

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Gradient — sits above the scrolling content, fades from the
          // team color at the top down to transparent. Anything scrolling
          // underneath fades out behind it near the top of the screen.
          Positioned(
            top: 0, left: 0, right: 0, height: 550,
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

          // ── Full-bleed scrollable content — starts at the very top so it
          // scrolls underneath the fixed header below. Each tab pads its own
          // scroll view by `_headerHeight` so its first item starts visually
          // below the header instead of being hidden underneath it.
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(team: team, topPadding: _headerHeight),
                MatchesTab(team: team, topPadding: _headerHeight),
                StandingTab(team: team, topPadding: _headerHeight),
                SquadTab(team: team, topPadding: _headerHeight),
                AnalysisTab(team: team, topPadding: _headerHeight),
              ],
            ),
          ),

          // ── Fixed header — logo/name/position + tab bar. Always on top,
          // never scrolls.
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                key: _headerKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
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
                                team?['name'],
                                style: Heading4.style,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                        ),
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
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerLeft, child: _tabBar),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}