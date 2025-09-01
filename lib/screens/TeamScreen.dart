import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:onetouch/screens/TeamScreen_tabs/Overview.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Matches.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Standing.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Squad.dart';
import 'package:onetouch/screens/TeamScreen_tabs/Analysis.dart';

final Map<String, Map<String, dynamic>> teamsData = {
  "FC Barcelona": {
    "id": 1,
    "name": "FC Barcelona",
    "position": "La Liga 1st",
    "logo": "assets/barca_logo.svg",
    "rankChange": 1,
    "highlight": {
      "title": "Manchester United v. Brighton | PREMIER LEAGUE",
      "source": "NBC Sports",
      "time": "1 day ago",
      "image": "assets/highlight1.png",
    },
  },
};

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

  Future<void> fetchTeamData() async {
    final url =
        'https://3e6a1be77d44.ngrok-free.app/api/teams/${widget.teamId}/overview';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonMap = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          team = jsonMap;
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
  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: 5, vsync: this);

    fetchTeamData(); // <-- THIS LINE SHOULD BE HERE
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
          // Top gradient background (fades out as you scroll)
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
                    colors: [
                      Color(0xE5DB0030),
                      Color(0x00B40000),
                    ],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),

          // Coordinated scrolling: AppBar hides, TabBar stays sticky
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // Floating AppBar (hides on downward scroll, snaps back on slight up)
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor:
                Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                pinned: false, // not pinned -> will hide
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99B40000),
                        Color(0x00B40000),
                      ],
                    ),
                  ),
                ),
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        team?["logo"] as String,
                        height: 52,
                        width: 53,
                        clipBehavior: Clip.antiAlias,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(team?["name"] as String, style: Heading4.style),
                          // FIX: rankChange key casing
                          Text(
                            "${team?["position"]} ${team?["rankChange"]}",
                            style: Body2.style,
                          ),
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

              // Sticky TabBar (stays while content scrolls)
              SliverPersistentHeader(
                pinned: false, // keep TabBar visible
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

            // Tab content; each tab can scroll independently but stays under sticky TabBar
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

// Sticky Tab Bar Delegate (unchanged behavior, reused for NestedScrollView)
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