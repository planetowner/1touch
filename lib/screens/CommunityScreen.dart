import 'package:onetouch/screens/CommunityScreen_utils/PostScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/screens/CommunityScreen_utils/AddPost.dart';
import 'package:onetouch/screens/CommunityScreen_utils/All.dart';

class Community extends StatefulWidget {
  const Community({super.key});

  @override
  State<Community> createState() => _CommunityState();
}

class _CommunityState extends State<Community>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
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
          MaterialPageRoute(builder: (context) => const Addpost()),
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
                      Color(0xE5DB0030), // Deep Red
                      Color(0x00B40000), // Transparent
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
                      colors: [Color(0x99B40000), Color(0x00B40000)],
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

              // "Team Info" section with logo, LIVE, followers
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/barca_logo.svg',
                        height: 48,
                        width: 48,
                        placeholderBuilder: (_) =>
                            const CircularProgressIndicator(),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text("Team Name", style: Heading4.style),
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
                            ),
                            const SizedBox(height: 4),
                            Text("1.4M Followers", style: Body2.style),
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
            body: All(selectedTabIndex: _selectedTabIndex),
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
