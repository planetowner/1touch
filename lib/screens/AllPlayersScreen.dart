import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/playerdata.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/index.dart';

class PlayerCard extends StatefulWidget {
  final Player player;

  const PlayerCard({super.key, required this.player});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  int currentTabIndex = 0;

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
    _tabController.addListener(() {
      setState(() {
        currentTabIndex = _tabController.index;
      });
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
    double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    double gradientOpacity = 1.0 - opacityFactor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Global gradient behind everything including tab bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 333,
            child: AnimatedOpacity(
              opacity: gradientOpacity,
              duration: const Duration(milliseconds: 50),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.50, 1.00),
                    end: Alignment(0.50, 0.00),
                    colors: [
                      widget.player.teamColor[0].withOpacity(0.4),
                      widget.player.teamColor[1].withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          DefaultTabController(
            length: 4,
            child: NestedScrollView(
              controller: _scrollController,
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                  elevation: 0,
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: 100,
                  flexibleSpace: LayoutBuilder(
                    builder: (context, constraints) {
                      return Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(widget.player.fullName, style: Heading3.style),
                              const Spacer(),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.star_outline, size: 32, color: Colors.white),
                              ),
                              IconButton(
                                onPressed: () => context.push('/search'),
                                icon: const Icon(Icons.search, size: 32, color: Colors.white),
                              ),
                              IconButton(
                                onPressed: () => context.push('/compare', extra: widget.player.fullName,),
                                icon: const Icon(Icons.safety_divider, size: 32, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SliverPersistentHeader(
                  floating: true,
                  pinned: false,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey,
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
                        Tab(text: "Analysis"),
                        Tab(text: "Matches"),
                        Tab(text: "Career"),
                      ],
                      tabAlignment: TabAlignment.start,
                    ),
                    opacityFactor: opacityFactor, // ADD THIS
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  PlayerOverviewTab(player: widget.player),
                  AnalysisTab(player: widget.player),
                  CareerTab(player: widget.player),
                  CareerTab(player: widget.player),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final double opacityFactor;

  _TabBarDelegate(this._tabBar, {required this.opacityFactor});

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.opacityFactor != opacityFactor;
  }
}
