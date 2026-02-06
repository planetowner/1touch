import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class Players extends StatefulWidget {
  const Players({super.key});

  @override
  State<Players> createState() => _PlayersState();
}

class _PlayersState extends State<Players> {
  late ScrollController _scrollController;
  double _scrollOffset = 0.0;
  bool showAllPlayers = false;

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

  final List<String> leagues = [
    "Premier League",
    "La Liga",
    "Bundesliga",
    "Ligue 1",
    "Serie A"
  ];
  final List<String> seasons = ["2024/2025", "2023/2024", "2022/2023"];
  final List<String> positions = ["FW", "MF", "DF", "GK"];

  String selectedLeague = "Premier League";
  String selectedSeason = "2024/2025";
  String selectedPositions = "FW";

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150).clamp(0.0, 1.0);
    List<String> selectedFilters = [selectedLeague, selectedSeason, selectedPositions];

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: AnimatedOpacity(
              opacity: (1 - opacityFactor),
              duration: Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD82457), Color(0x00D82457)
                    ],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverAppBar(
                backgroundColor:
                Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFD82457), Color(0x00D82457)
                      ],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: EdgeInsets.only(left: 8, top: 30),
                  child: SvgPicture.asset(
                    'assets/app_logo.svg',
                    height: 23,
                    width: 120,
                    clipBehavior: Clip.antiAlias,
                  ),
                ),
                actions: [
                  Padding(
                    padding: EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
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
                          icon: const Icon(Icons.account_circle_outlined, size: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text("FAVORITE PLAYERS",
                                style: Body2_b.style),
                            Spacer(),
                            IconButton(
                                onPressed: () {
                                  debugPrint("nothing");
                                },
                                icon: const Icon(
                                  Icons.add,
                                  size: 24,
                                  color: Colors.white,
                                ))
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 148,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 5,
                              itemBuilder: (context, index) {
                                if (index == 0) {
                                  return GestureDetector(
                                    onTap: () {
                                      context.push('/players/son');
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Column(
                                        children: [
                                          const CircleAvatar(
                                            radius: 37,
                                            // backgroundImage: NetworkImage(
                                            //   'https://upload.wikimedia.org/wikipedia/commons/5/5c/Son_Heung-min_2019.jpg',
                                            // ),
                                            backgroundColor: Colors.white24,
                                          ),
                                          const SizedBox(height: 8),
                                          Column(
                                            children: [
                                              Text(
                                                "Heungmin",
                                                style: Body1.style,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                "Son",
                                                style: Body1.style,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  );
                                }

                                // Fallback dummy players
                                return Padding(
                                  padding: const EdgeInsets.only(right: 16),
                                  child: Column(
                                    children: [
                                      const CircleAvatar(radius: 37, backgroundColor: Colors.white24),
                                      const SizedBox(height: 8),
                                      Column(
                                        children: [
                                          Text(
                                            "First name",
                                            style: Body1.style,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            "Last Name",
                                            style: Body1.style,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                );
                              },
                          ),
                        ),
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
                              onPressed: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true, // allow full-height
                                backgroundColor: Color(0xFF272828),
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                                ),
                                builder: (context) {
                                  return FractionallySizedBox(
                                    heightFactor: 0.85, // full screen height
                                    child: buildFilterSelector(),
                                  );
                                },
                              )
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          children: selectedFilters.map((filter) {
                            return filterTag(filter, () {
                              setState(() {
                                selectedFilters.remove(filter);
                              });
                            });
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        buildPlayerRankingBox(
                            ['player1', 'player2', 'player3', 'player4', 'player5', 'player6', "player 7"]
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
                          height: 160,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              onesToWatchCard(
                                playerName: "Heungmin Son",
                                teamName: "Tottenham",
                                shirtNumber: 7,
                                imageUrl: "https://link-to-player-image.jpg",
                              ),
                              onesToWatchCard(
                                playerName: "Heungmin Son",
                                teamName: "Tottenham",
                                shirtNumber: 7,
                                imageUrl: "https://link-to-player-image.jpg",
                              ),
                              onesToWatchCard(
                                playerName: "Heungmin Son",
                                teamName: "Tottenham",
                                shirtNumber: 7,
                                imageUrl: "https://link-to-player-image.jpg",
                              ),
                              onesToWatchCard(
                                playerName: "Heungmin Son",
                                teamName: "Tottenham",
                                shirtNumber: 7,
                                imageUrl: "https://link-to-player-image.jpg",
                              ),
                              // more cards...
                            ],
                          ),
                        ),
                        const SizedBox(height: 144,),
                      ],
                    ),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget buildFilterSelector() {
    return StatefulBuilder(builder: (context, setModalState) {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 80),
            // reserve space for button
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 32
                      ),
                      Text("Filter", style: Heading5.style),
                      Icon(Icons.close, color: Colors.white,)
                    ],
                  ),
                  const SizedBox(height: 48),

                  // LEAGUE
                  Text("LEAGUE", style: Body2_b.style),
                  const SizedBox(height: 16),
                  ...List.generate(leagues.length, (index) {
                    final league = leagues[index];
                    final isSelected = selectedLeague == league;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(league, style: Body1.style),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                          onTap: () => setModalState(() => selectedLeague = league),
                        ),
                        if (index != leagues.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Container(
                              height: 1,
                              color: Color(0xFF3D3D3D),
                            ),
                          ),
                      ],
                    );
                  }),

                  const SizedBox(height: 48),

                  // SEASON
                  Text("SEASON", style: Body2_b.style),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      // Optional dropdown
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(selectedSeason, style: Body1.style),
                            SizedBox(width: 8,),
                            const Icon(Icons.expand_more, color: Colors.white),
                          ],
                        ),
                        Icon(Icons.check, color: Colors.white,)
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(color: Color(0xFF3D3D3D)),

                  // POSITION
                  const SizedBox(height: 48),
                  Text("POSITION", style: Body2_b.style),
                  const SizedBox(height: 16),
                  ...List.generate(positions.length, (index) {
                    final position = positions[index];
                    final isSelected = selectedPositions == position;

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(position, style: Body1.style),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                          onTap: () => setModalState(() => selectedPositions = position),
                        ),
                        if (index != position.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Container(
                              height: 1,
                              color: Color(0xFF3D3D3D),
                            ),
                          ),
                      ],
                    );
                  }),

                  const SizedBox(height: 48), // extra scroll padding
                ],
              ),
            ),
          ),

          // Fixed Button
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text("UPDATE FILTER",
                    style: Body2_b.style.copyWith(color: Colors.black)),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget filterTag(String label, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16,8,16,8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Body2_b.style
          ),
        ],
      ),
    );
  }

  Widget buildPlayerRankingBox(List<String> players) {
    final visibleCount = showAllPlayers ? players.length : 5;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text("${i + 1}", style: Heading3.style),
                  const SizedBox(width: 16),
                  const CircleAvatar(radius: 20, backgroundColor: Colors.white24),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(players[i], style: Heading5.style),
                      const SizedBox(height: 4),
                      Text("Team Name • ##", style: Body2.style),
                    ],
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      '99.7',
                      textAlign: TextAlign.right,
                      style: Heading5.style
                    ),
                  )
                ],
              ),
            ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: const Color(0xFF1E1E1E),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) {
                  return FractionallySizedBox(
                    heightFactor: 0.85,
                    child: buildFullRankingPopup(),
                  );
                },
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 6),
                Text(
                  "See All",
                  style: Body2.style,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget onesToWatchCard({
    required String playerName,
    required String teamName,
    required int shirtNumber,
    required String imageUrl,
  }) {
    return Container(
      width: 135,
      height: 180,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF2A2A2A),
        // image: DecorationImage(
        //   image: NetworkImage(imageUrl),
        //   fit: BoxFit.cover,
        //   colorFilter: ColorFilter.mode(
        //     Colors.black.withOpacity(0.55), // dimmed background
        //     BlendMode.darken,
        //   ),
        // ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "#$shirtNumber",
              style: Heading4.style
            ),
            const Spacer(),
            Text(
              playerName,
              style: Heading5.style,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              "$teamName • $shirtNumber",
              style: Body2.style
            ),
          ],
        ),
      ),
    );
  }

  Widget buildFullRankingPopup() {
    return Scaffold(
      backgroundColor: const Color(0xFF272828),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32), // fake spacer to balance X button
                  const Text("1Touch Ranking", style: Heading5.style),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                // height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Look for players",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.50)),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.search, color: Colors.white),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Ranking List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 20,
                itemBuilder: (context, index) {
                  final rank = index + 1;
                  final showStar = rank == 2 || rank == 6;
                  final showArrow = rank == 1 || rank == 4 || rank == 6;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        // Rank Number
                        Text(
                          "$rank",
                          style: Heading4.style,
                        ),
                        const SizedBox(width: 8),

                        // Rank Icon (up arrow or star)
                        if (showArrow)
                          const Icon(Icons.arrow_drop_up, color: Colors.blueAccent),
                        if (!showArrow)
                          const SizedBox(width: 24),

                        // Avatar
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white24,
                          // backgroundImage: NetworkImage('...'), // future
                        ),

                        const SizedBox(width: 16),

                        // Name + Team
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text("Player Name", style: Heading5.style),
                              SizedBox(height: 2),
                              Text("Team Name • ##", style: Body2.style),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            if (!showArrow && showStar)
                              const Icon(Icons.star, color: Colors.white),
                          ],
                        ),

                        // Score
                        Text(
                          (99.7 - index * 0.3).toStringAsFixed(1),
                          style: Heading5.style,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
