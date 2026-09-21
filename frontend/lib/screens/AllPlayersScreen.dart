import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/data/players/player_detail_repository_provider.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
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

class PlayerCard extends StatefulWidget {
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  final PlayerDetailRepository? detailRepository;
  final PlayerDetail? initialDetail;

  const PlayerCard(
      {super.key,
      this.player,
      this.playerId,
      this.detailRepository,
      this.initialDetail});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  int currentTabIndex = 0;
  late PlayerDetailStore _detailStore;
  bool get isOverviewTab => currentTabIndex == 0;

  @override
  void initState() {
    super.initState();
    _detailStore = PlayerDetailStore(
        playerId: widget.id,
        repository: widget.detailRepository,
        initial: widget.initialDetail);
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
  void didUpdateWidget(covariant PlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.detailRepository != widget.detailRepository) {
      _detailStore = PlayerDetailStore(
          playerId: widget.id,
          repository: widget.detailRepository,
          initial: widget.initialDetail);
    }
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
    final pageBackground = mainPageBackground(context);
    const gradientForeground = AppPalette.white;
    final blendColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
    final gradientColor = Color.lerp(
        (widget.player?.teamColor.first ?? const Color(0xFFD82457)),
        blendColor,
        0.30)!;

    final double topInset = MediaQuery.of(context).padding.top;
    final double overviewGradientHeight =
        playerDetailOverviewGradientHeight(topInset);
    final double gradientHeight = isOverviewTab
        ? overviewGradientHeight
        // Other tabs: fade ends just past the tab bar.
        : topInset + _playerDetailAppBarHeight + _playerDetailTabBarHeight;

    return PlayerDetailScope(
        store: _detailStore,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: pageBackground,
          body: Stack(
            children: [
              // Global gradient behind everything including tab bar.
              // AnimatedPositioned smoothly eases the height between the tall
              // Overview gradient and the compact one on the other tabs, so the
              // fade point glides into place instead of snapping on tab change.
              AnimatedPositioned(
                key: const ValueKey('player-detail-gradient-position'),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 0,
                left: 0,
                right: 0,
                height: gradientHeight,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: gradientOpacity,
                    duration: const Duration(milliseconds: 50),
                    child: Container(
                      key: const ValueKey('player-detail-gradient'),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            gradientColor,
                            gradientColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Main content
              NestedScrollView(
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
                      playerId: widget.id,
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
                    PlayerOverviewTab(
                        player: widget.player,
                        playerId: widget.id,
                        onMatches: () => _tabController.animateTo(2)),
                    AnalysisTab(player: widget.player, playerId: widget.id),
                    MatchesTab(player: widget.player, playerId: widget.id),
                    CareerTab(player: widget.player, playerId: widget.id),
                  ],
                ),
              ),
            ],
          ),
        ));
  }
}

class PlayerScreenHeader extends StatelessWidget {
  const PlayerScreenHeader(
      {super.key,
      this.player,
      this.playerId,
      required this.horizontalPadding,
      required this.foregroundColor});
  final Player? player;
  final int? playerId;
  final double horizontalPadding;
  final Color foregroundColor;
  @override
  Widget build(BuildContext context) {
    final store = PlayerDetailScope.maybeOf(context)!;
    final id = playerId ?? player?.externalPlayerId;
    return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 0, horizontalPadding, 24),
            child: Row(children: [
              Expanded(
                  child: FutureBuilder<PlayerDetail>(
                      future: id == null ? null : store.load(null),
                      builder: (_, snapshot) => Text(
                          snapshot.data?.profile.name ??
                              player?.fullName ??
                              'Player',
                          style:
                              Heading3.style.copyWith(color: foregroundColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis))),
              if (id != null)
                PlayerFollowButton(playerId: id, color: foregroundColor),
              IconButton(
                  key: const ValueKey('player-search-button'),
                  onPressed: () async {
                    final candidate =
                        await showModalBottomSheet<PlayerCandidate>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => PlayerPickerSheet(
                                repository: store.repository ??
                                    playerDetailRepository));
                    if (candidate != null && context.mounted) {
                      context.push('/players/${candidate.id}');
                    }
                  },
                  icon: Icon(Icons.search, size: 32, color: foregroundColor)),
              IconButton(
                  key: const ValueKey('player-compare-button'),
                  onPressed: id == null
                      ? null
                      : () => context.push('/compare', extra: '$id'),
                  icon: Icon(Icons.safety_divider,
                      size: 32, color: foregroundColor)),
            ])));
  }
}

class PlayerFollowButton extends StatefulWidget {
  const PlayerFollowButton(
      {super.key,
      required this.playerId,
      required this.color,
      this.controller});
  final int playerId;
  final Color color;
  final PlayerFollowingController? controller;
  @override
  State<PlayerFollowButton> createState() => _PlayerFollowButtonState();
}

class _PlayerFollowButtonState extends State<PlayerFollowButton> {
  PlayerFollowingController get controller =>
      widget.controller ?? playerFollowingController;
  @override
  void initState() {
    super.initState();
    if (!controller.loaded) controller.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: controller,
      builder: (_, __) => IconButton(
          key: const Key('player-follow-button'),
          tooltip: controller.contains(widget.playerId)
              ? 'Unfollow player'
              : 'Follow player',
          onPressed: controller.loading
              ? null
              : () async {
                  try {
                    await controller.toggle(widget.playerId);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Could not save favorites')));
                    }
                  }
                },
          icon: Icon(
              controller.contains(widget.playerId)
                  ? Icons.star
                  : Icons.star_outline,
              size: 32,
              color: widget.color)));
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
