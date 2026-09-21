// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/data/players/player_detail_repository.dart';
import 'package:onetouch/data/players/player_directory_repository.dart';
import 'package:onetouch/features/player/player_following_controller.dart';
import 'package:onetouch/features/player/player_directory_widgets.dart';
import 'package:onetouch/features/player/player_picker_sheet.dart';
import 'package:onetouch/models/player_detail.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';

import '../core/favorite_team.dart';

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
  double _scrollOffset = 0.0;

  Color _teamColor = const Color(0xFFD82457);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    _teamColor = Color(
      teamRepository.requireById(FavoriteTeam.id.value).primaryColor,
    );
    // This tab stays alive in the bottom-nav shell, so listen for favorite
    // team switches made elsewhere (e.g. HomeScreen) instead of only
    // resolving the color once.
    FavoriteTeam.id.addListener(_handleFavoriteTeamChanged);
  }

  void _handleFavoriteTeamChanged() {
    setState(() {
      _teamColor = Color(
        teamRepository.requireById(FavoriteTeam.id.value).primaryColor,
      );
    });
  }

  @override
  void dispose() {
    FavoriteTeam.id.removeListener(_handleFavoriteTeamChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final gradientHeight = responsiveBrandGradientHeight(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gradientHeight,
            child: AnimatedOpacity(
              opacity: 1 - opacityFactor,
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: const ValueKey('players-brand-gradient'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_teamColor, _teamColor.withAlpha(0)],
                    stops: const [0.0, 0.65],
                  ),
                ),
              ),
            ),
          ),

          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App bar
              SliverAppBar(
                backgroundColor: Color.lerp(
                    Colors.transparent, pageBackground, opacityFactor),
                foregroundColor: AppPalette.white,
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                centerTitle: false,
                titleSpacing: 0,
                flexibleSpace: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [_teamColor, _teamColor.withAlpha(0)],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 120,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
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
                          icon: const Icon(
                            Icons.search,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: () => context.push('/compare'),
                          icon: const Icon(Icons.safety_divider,
                              size: 32, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => context.push('/profile'),
                          icon: const Icon(
                            Icons.account_circle_outlined,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Body content
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
                            repository:
                                widget.repository ?? playerDirectoryRepository),
                        const SizedBox(height: 48),
                        PlayersToWatch(
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
        ],
      ),
    );
  }
}
