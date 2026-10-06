import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/models/player.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/contracts/team_contract_repository.dart';
import 'package:onetouch/features/player/player_detail_view.dart';
import 'package:onetouch/screens/AllPlayersScreen_tabs/index.dart';
import 'package:onetouch/l10n/app_localizations.dart';

const double _playerDetailAppBarHeight = 100;
const double _playerDetailTabBarHeight = 48;
const double _playerDetailOverviewPadding = 24;
const double _playerDetailTopBlockHeight = 172;

double playerDetailOverviewGradientHeight(
  double topInset, {
  double topBlockHeight = _playerDetailTopBlockHeight,
}) =>
    topInset +
    _playerDetailAppBarHeight +
    _playerDetailTabBarHeight +
    _playerDetailOverviewPadding +
    topBlockHeight;

double playerDetailHeaderGradientHeight(double topInset) =>
    topInset + _playerDetailAppBarHeight + _playerDetailTabBarHeight;

double _playerGradientProgress(TabController controller) {
  final value = controller.animation!.value;
  if (!controller.indexIsChanging) return value.clamp(0.0, 1.0);
  final from = controller.previousIndex;
  final to = controller.index;
  final start = from == 0 ? 0.0 : 1.0;
  final end = to == 0 ? 0.0 : 1.0;
  if (start == end) return start;
  final fraction = ((value - from) / (to - from)).clamp(0.0, 1.0);
  return start + (end - start) * fraction;
}

class PlayerCard extends StatefulWidget {
  final Player? player;
  final int? playerId;
  int? get id => playerId ?? player?.externalPlayerId;
  final PlayerDetailRepository? detailRepository;
  final TeamContractRepository? contractRepository;
  final PlayerDetail? initialDetail;

  const PlayerCard(
      {super.key,
      this.player,
      this.playerId,
      this.detailRepository,
      this.contractRepository,
      this.initialDetail});

  @override
  State<PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<PlayerCard>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late TabController _tabController;
  double _scrollOffset = 0.0;
  double _overviewTopBlockHeight = _playerDetailTopBlockHeight;
  int _matchesScrollResetToken = 0;
  late PlayerDetailStore _detailStore;

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

  void _openMatchesAtTop() {
    setState(() => _matchesScrollResetToken++);
    void resetHeaderWhenTabSettles() {
      if (_tabController.indexIsChanging) return;
      _tabController.removeListener(resetHeaderWhenTabSettles);
      // Matches 목록의 스크롤을 먼저 초기화한 뒤 접힌 앱바를 맨 위로 펼쳐요.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        });
      });
    }

    _tabController.addListener(resetHeaderWhenTabSettles);
    _tabController.animateTo(2);
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
    final appBarExtent = topInset + _playerDetailAppBarHeight;
    final headerExtent = playerDetailHeaderGradientHeight(topInset);
    final splitColor = Color.lerp(
      gradientColors.last,
      gradientColors.first,
      appBarExtent / headerExtent,
    )!;
    final appBarGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [gradientColors.last, splitColor],
    );
    final tabBarGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [splitColor, gradientColors.first],
    );
    final overviewGradientHeight = playerDetailOverviewGradientHeight(
      topInset,
      topBlockHeight: _overviewTopBlockHeight,
    );
    final tabAnimation = _tabController.animation!;

    return PlayerDetailScope(
        store: _detailStore,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: pageBackground,
          body: Stack(
            children: [
              Positioned(
                key: const ValueKey('player-detail-overview-gradient-position'),
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: tabAnimation,
                    builder: (context, _) {
                      final progress = _playerGradientProgress(_tabController);
                      if (progress == 1) return const SizedBox.shrink();
                      return TweenAnimationBuilder<double>(
                        tween: Tween(end: opacityFactor),
                        duration: const Duration(milliseconds: 50),
                        builder: (context, scrollFade, _) => Opacity(
                          opacity: 1 - scrollFade * (1 - progress),
                          child: Container(
                            key: const ValueKey(
                                'player-detail-overview-gradient'),
                            height: overviewGradientHeight +
                                (headerExtent - overviewGradientHeight) *
                                    progress,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: gradientColors,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              NestedScrollView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    backgroundColor: scrollingAppBarBackground(
                        context, pageBackground, opacityFactor),
                    elevation: 0,
                    floating: true,
                    snap: true,
                    pinned: false,
                    toolbarHeight: _playerDetailAppBarHeight,
                    flexibleSpace: AnimatedBuilder(
                      animation: tabAnimation,
                      builder: (context, child) => Container(
                        key: const ValueKey('player-detail-gradient'),
                        decoration: BoxDecoration(
                          gradient: _playerGradientProgress(_tabController) >= 1
                              ? appBarGradient
                              : null,
                        ),
                        child: child,
                      ),
                      child: PlayerScreenHeader(
                        player: widget.player,
                        playerId: widget.id,
                        horizontalPadding: 24,
                        foregroundColor: gradientForeground,
                      ),
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
                        tabs: [
                          Tab(text: tr(context, "Overview")),
                          Tab(text: tr(context, "Analysis")),
                          Tab(text: playerTabLabel(context, "Matches")),
                          Tab(text: tr(context, "Career")),
                        ],
                        tabAlignment: TabAlignment.start,
                      ),
                      controller: _tabController,
                      backgroundGradient: tabBarGradient,
                      backgroundColor: scrollingAppBarBackground(
                          context, pageBackground, opacityFactor),
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    PlayerOverviewTab(
                        player: widget.player,
                        playerId: widget.id,
                        contractRepository: widget.contractRepository,
                        onMatches: _openMatchesAtTop,
                        onTopBlockHeightChanged: (height) {
                          final nextHeight =
                              height < _playerDetailTopBlockHeight
                                  ? _playerDetailTopBlockHeight
                                  : height;
                          if (nextHeight == _overviewTopBlockHeight ||
                              !mounted) {
                            return;
                          }
                          setState(() => _overviewTopBlockHeight = nextHeight);
                        }),
                    AnalysisTab(player: widget.player, playerId: widget.id),
                    MatchesTab(
                      player: widget.player,
                      playerId: widget.id,
                      scrollResetToken: _matchesScrollResetToken,
                    ),
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
                          playerNameLabel(
                              context,
                              id,
                              snapshot.data?.profile.name ??
                                  player?.fullName ??
                                  'Player'),
                          style:
                              Heading3.style.copyWith(color: foregroundColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis))),
              if (id != null)
                PlayerFollowButton(playerId: id, color: foregroundColor),
              IconButton(
                  key: const ValueKey('player-search-button'),
                  onPressed: () => context.push('/search'),
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
              ? tr(context, 'Unfollow player')
              : tr(context, 'Follow player'),
          onPressed: controller.loading
              ? null
              : () async {
                  try {
                    await controller.toggle(widget.playerId);
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content:
                              Text(tr(context, 'Could not save favorites'))));
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
  final TabController controller;
  final Gradient? backgroundGradient;
  final Color? backgroundColor;

  _TabBarDelegate(
    this._tabBar, {
    required this.controller,
    required this.backgroundGradient,
    required this.backgroundColor,
  });

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return AnimatedBuilder(
      animation: controller.animation!,
      child: _tabBar,
      builder: (context, child) => Container(
        key: const ValueKey('player-detail-tab-gradient'),
        decoration: BoxDecoration(
          color:
              _playerGradientProgress(controller) >= 1 ? null : backgroundColor,
          gradient: _playerGradientProgress(controller) >= 1
              ? backgroundGradient
              : null,
        ),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return oldDelegate.controller != controller ||
        oldDelegate.backgroundGradient != backgroundGradient ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
