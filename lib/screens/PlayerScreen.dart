// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/features/PlayerScreenFeatures.dart';
import 'package:onetouch/models/player.dart';

import '../core/favorite_team.dart';

class Players extends StatefulWidget {
  const Players({super.key});

  @override
  State<Players> createState() => _PlayersState();
}

class _PlayersState extends State<Players> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final List<String> leagues = [
    "Premier League",
    "La Liga",
    "Bundesliga",
    "Ligue 1",
    "Serie A"
  ];
  final List<String> seasons = ["2025/2026", "2024/2025", "2023/2024"];
  final List<String> positions = ["FW", "MF", "DF", "GK"];

  String selectedLeague = "Premier League";
  String selectedSeason = "2025/2026";
  String selectedPosition = "FW";

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

  void _openFilterSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppPalette.lightGrey : AppPalette.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: FilterSheet(
          initialLeague: selectedLeague,
          initialSeason: selectedSeason,
          initialPosition: selectedPosition,
          leagues: leagues,
          seasons: seasons,
          positions: positions,
          onApply: (league, season, position) {
            setState(() {
              selectedLeague = league;
              selectedSeason = season;
              selectedPosition = position;
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    final pageBackground = mainPageBackground(context);
    final colors = Theme.of(context).colorScheme;
    final gradientHeight = responsiveBrandGradientHeight(context);
    final position = PlayerPosition.values.firstWhere(
      (value) => value.label == selectedPosition,
      orElse: () => PlayerPosition.forward,
    );
    final rankedPlayers = playerRepository.ranking
        .where((player) => player.leagueName == selectedLeague)
        .where((player) => player.positions.contains(position))
        .toList(growable: false);

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
                  padding: const EdgeInsets.only(left: 24, top: 30),
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
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/search'),
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
                        const FavoritePlayersSection(),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  const Flexible(
                                    child: Text(
                                      "1TOUCH RANKING",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Body2_b.style,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.help_outline,
                                    size: 20,
                                    color: colors.onSurface,
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 24,
                                    color: colors.onSurface,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.tune, color: colors.onSurface),
                              onPressed: _openFilterSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterPill(
                                  label: selectedLeague.toUpperCase(),
                                  onTap: _openFilterSheet),
                              const SizedBox(width: 12),
                              FilterPill(
                                  label: selectedSeason,
                                  onTap: _openFilterSheet),
                              const SizedBox(width: 12),
                              FilterPill(
                                  label: selectedPosition,
                                  onTap: _openFilterSheet),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        PlayerRankingBox(
                          players: rankedPlayers,
                        ),
                        const SizedBox(height: 48),
                        Row(
                          children: [
                            const Text(
                              "ONES TO WATCH",
                              style: Body2_b.style,
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.help_outline,
                                size: 16, color: colors.onSurface),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: playerRepository.onesToWatch
                                .map(
                                    (player) => OnesToWatchCard(player: player))
                                .toList(),
                          ),
                        ),
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
