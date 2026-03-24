import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/features/PlayerScreenFeatures.dart';

import '../data/playerdata.dart';

class Players extends StatefulWidget {
  const Players({super.key});

  @override
  State<Players> createState() => _PlayersState();
}

class _PlayersState extends State<Players> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  final List<String> leagues   = ["Premier League", "La Liga", "Bundesliga", "Ligue 1", "Serie A"];
  final List<String> seasons   = ["2024/2025", "2023/2024", "2022/2023"];
  final List<String> positions = ["FW", "MF", "DF", "GK"];

  String selectedLeague   = "Premier League";
  String selectedSeason   = "2024/2025";
  String selectedPosition = "FW";

  late final Player player;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF3D3D3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: FilterSheet(
          initialLeague:   selectedLeague,
          initialSeason:   selectedSeason,
          initialPosition: selectedPosition,
          leagues:   leagues,
          seasons:   seasons,
          positions: positions,
          onApply: (league, season, position) {
            setState(() {
              selectedLeague   = league;
              selectedSeason   = season;
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: 0, left: 0, right: 0, height: 400,
            child: AnimatedOpacity(
              opacity: 1 - opacityFactor,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD82457), Color(0x00D82457)],
                    stops: [0.0, 0.6],
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
                backgroundColor: Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD82457), Color(0x00D82457)],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: SvgPicture.asset('assets/app_logo.svg', height: 23, width: 120),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search, size: 32),
                        ),
                        IconButton(
                          onPressed: () => context.push('/compare', extra: player.fullName,),
                          icon: const Icon(Icons.safety_divider, size: 32, color: Colors.white),
                        ),
                        IconButton(
                          onPressed: () => context.push('/profile'),
                          icon: const Icon(Icons.account_circle_outlined, size: 32),
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
                            Row(
                              children: const [
                                Text("1TOUCH RANKING", style: Body2_b.style),
                                SizedBox(width: 8),
                                Icon(Icons.help_outline, size: 20, color: Colors.white),
                                SizedBox(width: 8),
                                Icon(Icons.keyboard_arrow_down, size: 24, color: Colors.white),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune, color: Colors.white),
                              onPressed: _openFilterSheet,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterPill(label: "ALL LEAGUES",   onTap: _openFilterSheet),
                              const SizedBox(width: 12),
                              FilterPill(label: "ALL SEASONS",   onTap: _openFilterSheet),
                              const SizedBox(width: 12),
                              FilterPill(label: "ALL POSITIONS", onTap: _openFilterSheet),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const PlayerRankingBox(
                          players: [
                            'Player1', 'Player2', 'Player3',
                            'Player4', 'Player5', 'Player6', 'Player7',
                          ],
                        ),
                        const SizedBox(height: 48),
                        Row(
                          children: const [
                            Text("ONES TO WATCH", style: Body2_b.style),
                            SizedBox(width: 8),
                            Icon(Icons.help_outline, size: 16, color: Colors.white),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: const [
                              OnesToWatchCard(playerName: "Heungmin Son", teamName: "Tottenham", shirtNumber: 7, imageUrl: ""),
                              OnesToWatchCard(playerName: "Heungmin Son", teamName: "Tottenham", shirtNumber: 7, imageUrl: ""),
                              OnesToWatchCard(playerName: "Heungmin Son", teamName: "Tottenham", shirtNumber: 7, imageUrl: ""),
                              OnesToWatchCard(playerName: "Heungmin Son", teamName: "Tottenham", shirtNumber: 7, imageUrl: ""),
                            ],
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