import 'package:onetouch/core/page_refresh.dart';
// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/main_tab_actions.dart';
import 'package:onetouch/core/app_header.dart';
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
    return Scaffold(
      backgroundColor: pageBackground,
      body: PageRefreshIndicator(
        onRefresh: _refreshPlayers,
        builder: (context, physics) => CustomScrollView(
          controller: _scrollController,
          physics: physics,
          slivers: [
            AppBrandSliverHeader(
              key: const ValueKey('players-app-bar'),
              logoKey: const ValueKey('players-app-logo'),
              pageBackground: pageBackground,
              actions: AppHeaderActions(children: [
                AppHeaderIconButton(
                  key: const ValueKey('players-search-button'),
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search),
                ),
                AppHeaderIconButton(
                  onPressed: () => context.push('/compare'),
                  icon: const Icon(Icons.safety_divider),
                ),
                AppHeaderIconButton(
                  key: const ValueKey('players-profile-button'),
                  onPressed: () => context.push('/profile'),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ]),
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
