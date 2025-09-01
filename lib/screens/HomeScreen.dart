import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/stylesheet_dark.dart';
import '../bodywidgets/bodywidget.dart' as bwg;
import '../data/teamdata.dart'; // Your model file path
import '../data/matchdata.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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

    fetchHomeData();
  }

  Future<void> fetchHomeData() async {
    try {
      final resp = await http.get(Uri.parse(
          'https://3e6a1be77d44.ngrok-free.app/api/teams/9/overview'));
      if (resp.statusCode == 200) {
        final jsonMap = json.decode(resp.body) as Map<String, dynamic>;
        final team = Team.fromJson(jsonMap);

        setState(() {
          realteam = [team]; // wrap it in a list
          isLoading = false;
        });
      } else {
        print("Failed to load data: ${resp.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching home data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF2C2C2C),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sync with your calendar?", style: Heading5.style),
                const SizedBox(height: 16),
                Text(
                  "We’ll add your favorite team’s upcoming matches straight to your calendar, so you never miss a kickoff. You’ll get notified before each game — no spam, no surprises.",
                  style: Body1.style,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("YES, SYNC IT!", style: Body2_b.style.copyWith(color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text("CANCEL", style: Body2_b.style),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                    colors: [Color(0xE5DB0030), Color(0x00B40000)],
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
                      colors: [Color(0x99B40000), Color(0x00B40000)],
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
                  const SectionHeader(title: "FAVORITE TEAMS"),
                  bwg.MyTeams(teams: realteam),
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
                          onPressed: () => _showSyncDialog(context),
                        ),
                      ),
                    ],
                  ),
                  bwg.HardcodedCalendar(),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "HIGHLIGHTS"),
                  bwg.MyHighlights(highlights: team),
                  const SizedBox(height: 32),
                  const SectionHeader(title: "NEWS"),
                  bwg.MyNews(news: team),
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
      child: Text(title, style: Body1_b.style),
    );
  }
}
