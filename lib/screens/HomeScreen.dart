import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import '../core/stylesheet_dark.dart';
import '../data/teamdata.dart'; // Your model file path
import '../data/matchdata.dart';
import 'package:onetouch/features/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

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

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  List<Team> realteam = [];
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    // 🔹 Toggle here for testing
    // fetchHomeData();
    loadFakeData();
  }

  void loadFakeData() {
    final decoded = jsonDecode(fakeTeamsJson) as List<dynamic>;
    final parsedTeams = decoded.map((t) => Team.fromJson(t)).toList();

    setState(() {
      realteam = parsedTeams;
      isLoading = false;
    });
  }


  // Future<void> fetchHomeData() async {
  //   try {
  //     final resp = await http.get(Uri.parse(
  //         'https://3e6a1be77d44.ngrok-free.app/api/teams/9/overview'));
  //     if (resp.statusCode == 200) {
  //       final jsonMap = json.decode(resp.body) as Map<String, dynamic>;
  //       final team = Team.fromJson(jsonMap);
  //
  //       setState(() {
  //         realteam = [team]; // wrap it in a list
  //         isLoading = false;
  //       });
  //     } else {
  //       print("Failed to load data: ${resp.statusCode}");
  //       setState(() => isLoading = false);
  //     }
  //   } catch (e) {
  //     print("Error fetching home data: $e");
  //     setState(() => isLoading = false);
  //   }
  // }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final List<List<Object>> team = [
      [
        "FC Barcelona",
        "La Liga 1st",
        "assets/barca_logo.svg",
        "100",
        "200",
        {
          "title": "Manchester United v. Brighton | PREMIER LEAGUE",
          "source": "NBC Sports",
          "time": "1 day ago",
          "image": "assets/highlight1.png"
        }
      ],
      [
        "FC Barcelona",
        "La Liga 1st",
        "assets/barca_logo.svg",
        "100",
        "200",
        {
          "title": "Manchester United v. Brighton | PREMIER LEAGUE",
          "source": "NBC Sports",
          "time": "1 day ago",
          "image": "assets/highlight1.png"
        }
      ],
    ];



    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);

    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final allMatches = realteam
        .where((t) => t.nextMatch != null)
        .map((t) => t.nextMatch!)
        .toList();

    MatchData? liveMatch;
    if (realteam.isNotEmpty && realteam[0].nextMatch != null) {
      final match = realteam[0].nextMatch!;
      final status = determineMatchStatus(DateTime.parse(match.date));

      if (status == 'LIVE') {
        liveMatch = match;
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD82457), Color(0x00D82457)],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor:
                Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD82457), Color(0x00D82457)],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 120,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            context.push('/search');
                          },
                          icon: const Icon(Icons.search, size: 32),
                        ),
                        // New Dropdown Feature
                        GestureDetector(
                          onTap: () => TeamSelectionSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                SvgPicture.asset(
                                  'assets/barca_logo.svg', // Replace with current team's logo
                                  height: 24,
                                  width: 24,
                                ),
                                const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            context.push('/profile');
                          },
                          icon: const Icon(Icons.account_circle_outlined,
                              size: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 48),
                  const SectionHeader(title: "FAVORITE TEAM"),
                  MyTeams(teams: realteam),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      const SectionHeader(title: "CALENDAR"),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: IconButton(
                          icon: const Icon(Icons.sync,
                              color: Colors.white, size: 24),
                          onPressed: () => SyncDialog.show(context),
                        ),
                      ),
                    ],
                  ),
                  HardcodedCalendar(),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "HIGHLIGHTS"),
                  MyHighlights(highlights: team),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "NEWS"),
                  MyNews(news: team),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Container(
                      width: 395,
                      height: 108,
                      padding: const EdgeInsets.all(8),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF3D3D3D),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Center(
                        child: Text("Ad", style: Heading4.style),
                      ),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Text(title, style: Body2_b.style),
    );
  }
}