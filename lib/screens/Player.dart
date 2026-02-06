import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/playerdata.dart';
import 'Player_tabs/Overview.dart';
import 'Player_tabs/Anal.dart';
import 'Player_tabs/Career.dart';

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

    _tabController = TabController(length: 3, vsync: this);
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          controller: _scrollController,
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor:
              Color.lerp(Colors.transparent, Colors.black, opacityFactor),
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 100,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      if (currentTabIndex != 0)
                        AnimatedOpacity(
                          opacity: (1 - opacityFactor),
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(1.0, -0.00),
                                end: Alignment(1.0, 1.00),
                                colors: [
                                  widget.player.teamColor.withOpacity(1.0),
                                  widget.player.teamColor.withOpacity(0.85),
                                  widget.player.teamColor.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 24, bottom: 16),
                          child: Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(widget.player.fullName,
                                      style: Heading3.style),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 16, top: 15),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          // context.push('/search');
                        },
                        icon: const Icon(Icons.star_outline, size: 32),
                      ),
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
                        icon:
                        const Icon(Icons.account_circle_outlined, size: 32),
                      ),
                    ],
                  ),
                )
              ],
            ),
            SliverPersistentHeader(
              floating: true,
              pinned: false,
              delegate: _TabBarDelegate(TabBar(
                controller: _tabController,
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
                  Tab(text: "Overview"),
                  Tab(text: "Analysis"),
                  Tab(text: "Career"),
                ],
                tabAlignment: TabAlignment.start,
              )),
            ),
          ],
          body: TabBarView(
            controller: _tabController,
            children: [
              PlayerOverviewTab(player: widget.player),
              AnalysisTab(player: widget.player),
              CareerTab(player: widget.player),
            ],
          ),
        ),
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
      color: Colors.black,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
