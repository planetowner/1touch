import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../core/stylesheet_dark.dart';
import '../data/teamdata.dart';
import '../models/fixture.dart';
import '../models/mock_data.dart';
import 'package:onetouch/features/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  List<Team> myTeam = [];
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
    loadMockData();
  }

  void loadMockData() {
    // mock user 1001: favorite = Barcelona, following = Barcelona + Bayern
    final favoriteTeamId = mockUserProfiles
        .firstWhere((p) => p.userId == 1001)
        .favoriteTeamId;

    final followingIds = followingTeamIds(1001);

    final teams = followingIds.map((id) {
      final team = mockTeamById(id);
      final fixtures = fixturesByTeam(id);
      return Team(
        id: team.teamId,
        name: team.name,
        shortName: team.shortCode ?? '',
        imagePath: team.imagePath ?? '',
        nextMatch: fixtures.where((f) => f.status == FixtureStatus.upcoming).firstOrNull,
        lastMatch: fixtures.where((f) => f.status == FixtureStatus.past).lastOrNull,
      );
    }).toList();

    setState(() {
      myTeam = teams;
      isLoading = false;
    });
  }

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
        "TeamLogos/Barcelona.png",
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
        "TeamLogos/Barcelona.png",
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

    final allMatches = myTeam
        .expand((t) => fixturesByTeam(t.id))
        .toList()
      ..sort((a, b) => a.startingAt.compareTo(b.startingAt));

    Fixture? liveMatch;
    if (myTeam.isNotEmpty && myTeam[0].nextMatch != null) {
      final match = myTeam[0].nextMatch!;
      final status = determineMatchStatus(DateTime.parse(match.startingAt));

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
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Image.network(
                                  myTeam.isNotEmpty ? myTeam[0].imagePath : '',
                                  height: 24,
                                  width: 24,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    'TeamLogos/Barcelona.png',
                                    height: 24,
                                    width: 24,
                                  ),
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
                  MyTeams(teams: myTeam),
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
                  HardcodedCalendar(allMatches: allMatches),
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