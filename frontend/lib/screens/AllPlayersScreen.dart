import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/player_repository_provider.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/index.dart';

const double _playerDetailAppBarHeight = 100;
const double _playerDetailTabBarHeight = 48;
const double _playerDetailOverviewPadding = 16;
const double _playerDetailTopBlockHeight = 145;

double playerDetailOverviewGradientHeight(double topInset) =>
    topInset +
    _playerDetailAppBarHeight +
    _playerDetailTabBarHeight +
    _playerDetailOverviewPadding +
    _playerDetailTopBlockHeight;

double playerDetailTabGradientHeight(double topInset) =>
    topInset + _playerDetailAppBarHeight + _playerDetailTabBarHeight;

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
  bool get isOverviewTab => currentTabIndex == 0;

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
      if (!_tabController.indexIsChanging &&
          currentTabIndex != _tabController.index) {
        setState(() => currentTabIndex = _tabController.index);
      }
    });
    playerRepository.followedPlayerIds.addListener(_onFollowingChanged);
  }

  void _onFollowingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    playerRepository.followedPlayerIds.removeListener(_onFollowingChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientForeground = Theme.of(context).colorScheme.onSurface;
    final gradientColors = isDark
        ? const [Color(0xFF282929), Color(0x00282929)]
        : const [Color(0x333D3D3D), Color(0x003D3D3D)];
    final topInset = MediaQuery.paddingOf(context).top;
    final gradientHeight = isOverviewTab
        ? playerDetailOverviewGradientHeight(topInset)
        : playerDetailTabGradientHeight(topInset);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          AnimatedPositioned(
            key: const ValueKey('player-detail-gradient-position'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('player-detail-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: gradientColors,
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
              physics: const ClampingScrollPhysics(),
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  automaticallyImplyLeading: false,
                  backgroundColor: Color.lerp(
                    Colors.transparent,
                    pageBackground,
                    opacityFactor,
                  ),
                  elevation: 0,
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: _playerDetailAppBarHeight,
                  flexibleSpace: PlayerScreenHeader(
                    player: widget.player,
                    horizontalPadding: 24,
                    foregroundColor: gradientForeground,
                  ),
                ),
                SliverPersistentHeader(
                  floating: true,
                  pinned: false,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      labelColor: gradientForeground,
                      unselectedLabelColor: gradientForeground,
                      labelStyle: Heading5.style,
                      unselectedLabelStyle: Heading5.style,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      padding: const EdgeInsets.only(left: 8),
                      indicator: UnderlineTabIndicator(
                        borderSide: BorderSide(
                          color: gradientForeground,
                          width: 2,
                        ),
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
                    backgroundColor: pageBackground,
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  PlayerOverviewTab(player: widget.player),
                  AnalysisTab(player: widget.player),
                  MatchesTab(player: widget.player),
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

class PlayerScreenHeader extends StatelessWidget {
  final Player player;
  final double horizontalPadding;
  final Color foregroundColor;

  const PlayerScreenHeader({
    super.key,
    required this.player,
    required this.horizontalPadding,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: 24,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                player.fullName,
                style: Heading3.style.copyWith(color: foregroundColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: const Key('player-follow-button'),
              tooltip: playerRepository.isFollowing(player.id)
                  ? 'Unfollow player'
                  : 'Follow player',
              onPressed: () => playerRepository.toggleFollowing(player.id),
              icon: Icon(
                playerRepository.isFollowing(player.id)
                    ? Icons.star
                    : Icons.star_outline,
                size: 32,
                color: foregroundColor,
              ),
            ),
            IconButton(
              key: const ValueKey('player-search-button'),
              onPressed: () => context.push('/search'),
              icon: Icon(Icons.search, size: 32, color: foregroundColor),
            ),
            IconButton(
              key: const ValueKey('player-compare-button'),
              onPressed: () => context.push(
                '/compare',
                extra: player.id,
              ),
              icon: Icon(
                Icons.safety_divider,
                size: 32,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final double opacityFactor;
  final Color backgroundColor;

  _TabBarDelegate(
    this._tabBar, {
    required this.opacityFactor,
    required this.backgroundColor,
  });

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color.lerp(Colors.transparent, backgroundColor, opacityFactor),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.opacityFactor != opacityFactor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
