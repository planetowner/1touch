// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';

class Players extends StatefulWidget {
  const Players(
      {super.key,
      this.repository,
      this.detailRepository,
      this.followingController});
  final PlayerDirectoryRepository? repository;
  final PlayerDetailRepository? detailRepository;
  final PlayerFollowingController? followingController;

  @override
  State<Players> createState() => _PlayersState();
}

class _PlayersState extends State<Players> {
  late ScrollController _scrollController;
  final _rankingKey = GlobalKey<PlayerRankingPanelState>();
  final _watchKey = GlobalKey<PlayersToWatchState>();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    mainTabActions.addListener(_handleMainTabAction);
  }

  void _handleMainTabAction() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    _scrollController.jumpTo(position.minScrollExtent);
  }

  Future<void> _refreshPlayers() async {
    final controller = widget.followingController ?? playerFollowingController;
    await Future.wait<void>([
      controller.load(),
      if (_rankingKey.currentState case final ranking?) ranking.refresh(),
      if (_watchKey.currentState case final watch?) watch.refresh(),
    ]);
  }

  @override
  void dispose() {
    mainTabActions.removeListener(_handleMainTabAction);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: pageBackground,
      body: RefreshIndicator(
        onRefresh: _refreshPlayers,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              key: const ValueKey('players-app-bar'),
              backgroundColor: pageBackground,
              foregroundColor: colors.onSurface,
              elevation: 0,
              floating: true,
              snap: true,
              toolbarHeight: 80,
              centerTitle: false,
              titleSpacing: 0,
              flexibleSpace: ColoredBox(color: pageBackground),
              clipBehavior: Clip.antiAlias,
              title: Padding(
                padding: const EdgeInsets.only(left: 24),
                child: SvgPicture.asset(
                  'assets/app_logo.svg',
                  height: 23,
                  width: 120,
                  colorFilter: ColorFilter.mode(
                    colors.onSurface,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 24),
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('players-search-button'),
                        onPressed: () => context.push('/search'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.search,
                          size: 32,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => context.push('/compare'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(Icons.safety_divider,
                            size: 32, color: colors.onSurface),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        key: const ValueKey('players-profile-button'),
                        onPressed: () => context.push('/profile'),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: Icon(
                          Icons.account_circle_outlined,
                          size: 32,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerFavorites(
                          controller: widget.followingController ??
                              playerFollowingController,
                          searchRepository: widget.detailRepository),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            PlayerRankingPanel(
                                key: _rankingKey,
                                repository: widget.repository ??
                                    playerDirectoryRepository,
                                detailRepository: widget.detailRepository,
                                followingController:
                                    widget.followingController ??
                                        playerFollowingController),
                            const SizedBox(height: 48),
                            PlayersToWatch(
                              key: _watchKey,
                              repository: widget.repository ??
                                  playerDirectoryRepository,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
