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
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/models/player_detail.dart';

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
    if (mainTabActions.tabIndex != 2 || !_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.minScrollExtent);
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
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () async {
                          final player =
                              await showModalBottomSheet<PlayerCandidate>(
                                  context: context,
                                  isScrollControlled: true,
                                  builder: (_) => PlayerPickerSheet(
                                      repository: widget.detailRepository));
                          if (player != null && context.mounted) {
                            context.push('/players/${player.id}');
                          }
                        },
                        icon: Icon(
                          Icons.search,
                          size: 32,
                          color: colors.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/compare'),
                        icon: Icon(Icons.safety_divider,
                            size: 32, color: colors.onSurface),
                      ),
                      IconButton(
                        onPressed: () => context.push('/profile'),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PlayerFavorites(
                          controller: widget.followingController ??
                              playerFollowingController,
                          searchRepository: widget.detailRepository),
                      const SizedBox(height: 32),
                      PlayerRankingPanel(
                          key: _rankingKey,
                          repository:
                              widget.repository ?? playerDirectoryRepository,
                          detailRepository: widget.detailRepository,
                          followingController: widget.followingController ??
                              playerFollowingController),
                      const SizedBox(height: 48),
                      PlayersToWatch(
                          key: _watchKey,
                          repository:
                              widget.repository ?? playerDirectoryRepository),
                      const SizedBox(height: 144),
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
