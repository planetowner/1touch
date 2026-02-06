import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onetouch/features/helper.dart';
import 'TeamScreen_tabs/index.dart';

import '../data/teamdata.dart';

String fakeTeamsJson = """
[
  {
    "id": 1,
    "name": "FC Barcelona",
    "short_code": "FCB",
    "image_path": "https://example.com/images/fcb.png",
    "league_id": 82,
    "standing": {
      "rank": 2,
      "points": 76,
      "wins": 24,
      "draws": 4,
      "losses": 6,
      "goal_for": 75,
      "goal_against": 32
    },
    "nextMatch": {
      "id": 101,
      "league_id": 82,
      "season_id": 2025,
      "round_id": 35,
      "venue_id": 500,
      "home_team_id": 1,
      "away_team_id": 2,
      "starting_at": "2025-09-15T20:00:00Z",
      "status": "not_started",
      "home_team": {
        "id": 1,
        "name": "FC Barcelona",
        "short_code": "FCB",
        "image_path": "https://example.com/images/fcb.png"
      },
      "away_team": {
        "id": 2,
        "name": "Real Madrid",
        "short_code": "RMA",
        "image_path": "https://example.com/images/rma.png"
      }
    },
    "lastMatch": null
  },
  {
    "id": 2,
    "name": "Real Madrid",
    "short_code": "RMA",
    "image_path": "https://example.com/images/rma.png",
    "league_id": 82,
    "standing": {
      "rank": 1,
      "points": 80,
      "wins": 26,
      "draws": 2,
      "losses": 6,
      "goal_for": 82,
      "goal_against": 28
    },
    "nextMatch": null,
    "lastMatch": null
  }
]
""";

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

  // ✅ initialize and add the view-model map your UI uses
  List<Team> teams = [];
  Map<String, dynamic>? team;
  bool isLoading = true;

  Future<void> fetchTeamData() async {
    final url =
        'https://3e6a1be77d44.ngrok-free.app/api/teams/${widget.teamId}/overview';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body) as Map<String, dynamic>;
        final parsed = Team.fromJson(jsonMap); // ✅ parse API object
        final int leagueId = parsed.leagueId;
        final int? rank = parsed.standing?['rank'] as int?;
        final String leagueName = {
          8: "Premier League",
          82: "La Liga",
          301: "Serie A",
          384: "Bundesliga",
          564: "Ligue 1",
        }[leagueId] ?? 'League';
        final position = rank != null ? "$leagueName ${ordinal(rank)}" : leagueName;

        setState(() {
          teams = [parsed]; // ✅ List<Team>
          team = {          // ✅ Map<String, dynamic> for your UI
            "id": parsed.id,
            "name": parsed.name,
            "position": position,
            "logo": parsed.imagePath, // network URL; we handle below
            "rankChange": 0,
            "raw": jsonMap,
          };
          isLoading = false;
        });
      } else {
        print("Failed to load team data: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error: $e");
      setState(() => isLoading = false);
    }
  }

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
    loadFakeData();     // local fake JSON
    // fetchTeamData(); // real API
  }

  void loadFakeData() {
    final decoded = jsonDecode(fakeTeamsJson) as List<dynamic>;
    final parsedTeams = decoded.map((t) => Team.fromJson(t)).toList();

    // pick the one matching route param; fallback to first
    final Team selected = parsedTeams.firstWhere(
          (t) => t.id == widget.teamId,
      orElse: () => parsedTeams.first,
    );

    // build position text (e.g., "La Liga 2nd")
    const leagueNames = {
      8: "Premier League",
      82: "La Liga",
      301: "Serie A",
      384: "Bundesliga",
      564: "Ligue 1",
    };

    final int leagueId = selected.leagueId;
    final int? rank = selected.standing?['rank'] as int?;
    final position = rank != null
        ? "${leagueNames[leagueId] ?? 'League'} ${ordinal(rank)}"
        : (leagueNames[leagueId] ?? 'League');

    setState(() {
      teams = parsedTeams; // ✅ keep the full parsed list if you need it later
      team = {
        "id": selected.id,
        "name": selected.name,
        "position": position,
        "logo": selected.imagePath, // URL; render as network if startsWith('http')
        "rankChange": 1,
        "raw": selected, // full Team object for tabs if needed
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

    if (team == null) { // ✅ exists now
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
            top: 0, left: 0, right: 0, height: 400,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFFD82457), Color(0x00D82457)],
                    stops: [0.0, 0.6],
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
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFFD82457), Color(0x00D82457)],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: Row(
                    children: [
                      // render network or asset seamlessly
                      (team?["logo"] as String).startsWith('http')
                          ? Image.network(
                        team?["logo"] as String,
                        height: 52, width: 53, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.error, color: Colors.red),
                      )
                          : SvgPicture.asset(
                        team?["logo"] as String,
                        height: 52, width: 53,
                        clipBehavior: Clip.antiAlias,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team?["name"] as String, style: Heading4.style),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${team?["position"]}", style: Body2.style),
                              Icon(Icons.arrow_drop_up, size: 16,),
                              Text(
                                  team?["rankChange"] != 0 ? " ${team?["rankChange"]}" : "",
                                  style: Eyebrow.style
                              ),
                            ],
                          )
                        ],
                      ),
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
                          icon: const Icon(Icons.star_outline, size: 32),
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
