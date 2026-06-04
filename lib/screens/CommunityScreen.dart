import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/screens/CommunityScreen_utils/All.dart';


bool _hasLiveFixture(int teamId) {
  return mockFixtures.any((f) =>
  (f.homeTeamId == teamId || f.awayTeamId == teamId) &&
      f.status == FixtureStatus.live);
}

String _formatFollowers(int count) {
  if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M Followers';
  if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K Followers';
  return '$count Followers';
}


class Community extends StatefulWidget {
  final int teamId;

  const Community({super.key, required this.teamId});

  @override
  State<Community> createState() => _CommunityState();
}

class _CommunityState extends State<Community>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  int _selectedTabIndex = 0;

  late Team _team;
  late bool _isLive;
  late int _followerCount;

  @override
  void initState() {
    super.initState();

    _team = mockTeamById(widget.teamId);
    _isLive = _hasLiveFixture(widget.teamId);
    _followerCount = mockUserFollowingTeams
        .where((f) => f.teamId == widget.teamId)
        .length;

    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        elevation: 0,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddPost()),
        ),
        child: SvgPicture.asset(
          'assets/addpost_icon.svg',
          height: 40,
          width: 40,
        ),
      ),
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
                    colors: [
                      Color(0xFFD82457), Color(0x00D82457)
                    ],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // AppBar: same as your current
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
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: SvgPicture.asset('assets/app_logo.svg',
                      height: 23, width: 120),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search, size: 32),
                        ),
                        IconButton(
                          onPressed: () => context.push('/profile'),
                          icon: const Icon(Icons.account_circle_outlined,
                              size: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ), // your existing AppBar

              // "Team Info"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _team.imagePath != null
                          ? Image.network(
                        _team.imagePath!,
                        height: 52,
                        width: 52,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'TeamLogos/Barcelona.png',
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        )
                      )
                          : const Icon(Icons.shield, color: Colors.white54, size: 52),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_team.name, style: Heading4.style),
                                if (_isLive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text("LIVE",
                                        style: Body2_b.style
                                            .copyWith(color: Colors.white)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(_formatFollowers(_followerCount),
                                style: Body2.style),
                          ],
                        ),
                      ),
                      const Icon(Icons.star_border, color: Colors.white),
                    ],
                  ),
                ),
              ),

              // Tab bar (sticky)
              SliverPersistentHeader(
                floating: true,
                pinned: false,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    onTap: (index) => setState(() => _selectedTabIndex = index),
                    isScrollable: true,
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
                      Tab(text: "All"),
                      Tab(text: "General"),
                      Tab(text: "Analysis"),
                      Tab(text: "News & Insights"),
                    ],
                    tabAlignment: TabAlignment.start,
                  ),
                ),
              ),
            ],
            body: All(
              selectedTabIndex: _selectedTabIndex,
              posts: mockPosts,
            ),
          )
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
