import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/players/mock_player_repository.dart';
import 'package:onetouch/features/player_image.dart';
import 'package:onetouch/features/helper.dart'; // Import helper
import 'package:onetouch/models/player.dart';

class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black],
                stops: [0.0, 0.4],
              ),
            ),
          ),
          const SafeArea(child: SearchContent()),
        ],
      ),
    );
  }
}

class SearchContent extends StatefulWidget {
  const SearchContent({super.key});

  @override
  State<SearchContent> createState() => _SearchContentState();
}

class _SearchContentState extends State<SearchContent> {
  final TextEditingController _searchController = TextEditingController();

  bool _isSearching = false;
  int _selectedIndex = 0;
  final List<String> _tabs = ["ALL", "PLAYERS", "TEAMS", "EVENTS"];

  final List<Map<String, dynamic>> _recentItems = [
    {
      'type': 'team',
      'teamId': 83,
      'name': 'FC Barcelona',
      'league': 'La Liga',
      'logo': 'TeamLogos/Barcelona.png'
    },
    {
      'type': 'match',
      'homeTeam': 'AAA',
      'homeLogo': 'TeamLogos/Barcelona.png',
      'awayTeam': 'BBB',
      'awayLogo': 'TeamLogos/Girona.png',
      'date': 'Sun, Sep 15',
      'time': '10:15 AM'
    },
  ];

  final List<Map<String, dynamic>> _searchResults = [
    {
      'type': 'match',
      'homeTeam': 'Man City',
      'homeLogo': 'TeamLogos/ManCity.png',
      'awayTeam': 'Liverpool',
      'awayLogo': 'TeamLogos/Liverpool.png',
      'time': '20:00',
      'date': 'Today'
    },
    {
      'type': 'team',
      'teamId': 14,
      'name': 'Manchester United',
      'logo': 'TeamLogos/ManUtd.png',
      'league': 'Premier League'
    },
  ];

  @override
  void initState() {
    super.initState();
    currentUserPreferences.followedTeamIds.addListener(_onFollowingChanged);
    playerRepository.followedPlayerIds.addListener(_onFollowingChanged);
  }

  void _onFollowingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    currentUserPreferences.followedTeamIds.removeListener(_onFollowingChanged);
    playerRepository.followedPlayerIds.removeListener(_onFollowingChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. SEARCH BAR AREA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _isSearching = value.isNotEmpty;
                      });
                    },
                    style: Body1.style,
                    cursorColor: const Color(0xFFD82457),
                    decoration: InputDecoration(
                      hintText: "Search...",
                      hintStyle: Body1.style.copyWith(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.white54),
                      suffixIcon: _isSearching
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _isSearching = false;
                                });
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. CONTENT AREA
          Expanded(
            child: _isSearching
                ? _buildSearchResultsLayout()
                : _buildRecentsLayout(),
          ),
        ],
      ),
    );
  }

  // --- LAYOUT A: RECENTS ---
  Widget _buildRecentsLayout() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      children: [
        const Text(
          "RECENTS",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        if (playerRepository.findById('lee-kang-in') case final player?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildPlayerCard(player),
          ),
        ..._recentItems.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: item['type'] == 'match'
                ? SearchMatchCard(
                    // Uses Helper Widget
                    homeTeam: item['homeTeam'],
                    homeLogo: item['homeLogo'],
                    awayTeam: item['awayTeam'],
                    awayLogo: item['awayLogo'],
                    date: item['date'],
                    time: item['time'],
                  )
                : _buildStandardCard(item),
          );
        }),
      ],
    );
  }

  // --- LAYOUT B: TABS + RESULTS ---
  Widget _buildSearchResultsLayout() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _selectedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? Colors.white : const Color(0xFF3D3D3D),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _tabs[index],
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        Expanded(child: _buildTabContent()),
      ],
    );
  }

  Widget _buildTabContent() {
    final players = playerRepository.search(_searchController.text);

    if (_selectedIndex == 0 || _selectedIndex == 1) {
      final includeOtherResults = _selectedIndex == 0;
      final itemCount =
          players.length + (includeOtherResults ? _searchResults.length : 0);
      return ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: itemCount,
        separatorBuilder: (c, i) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index < players.length) {
            return _buildPlayerCard(players[index]);
          }
          final result = _searchResults[index - players.length];
          return result['type'] == 'match'
              ? SearchMatchCard(
                  // Uses Helper Widget
                  homeTeam: result['homeTeam'],
                  homeLogo: result['homeLogo'],
                  awayTeam: result['awayTeam'],
                  awayLogo: result['awayLogo'],
                  date: result['date'],
                  time: result['time'],
                )
              : _buildStandardCard(result);
        },
      );
    }
    return Center(
        child: Text("${_tabs[_selectedIndex]} RESULTS",
            style: const TextStyle(color: Colors.white)));
  }

  Widget _buildPlayerCard(Player player) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/players/${player.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: ClipOval(child: PlayerImage(player: player)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.fullName,
                    style: Heading4.style.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${player.teamName} • #${player.jerseyNumber}',
                    style: Body2.style.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: playerRepository.isFollowing(player.id)
                  ? 'Unfollow player'
                  : 'Follow player',
              onPressed: () => playerRepository.toggleFollowing(player.id),
              icon: Icon(
                playerRepository.isFollowing(player.id)
                    ? Icons.star
                    : Icons.star_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
            Text(player.positionLabel, style: Body2.style),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardCard(Map<String, dynamic> item) {
    bool isTeam = item['type'] == 'team';
    final teamId = item['teamId'] as int?;
    final isFollowing = teamId != null &&
        currentUserPreferences.followedTeamIds.value.contains(teamId);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              image: DecorationImage(
                image: AssetImage(isTeam ? item['logo'] : item['image']),
                fit: BoxFit.cover,
                onError: (e, s) {},
              ),
            ),
            child: const Icon(Icons.image_not_supported,
                color: Colors.transparent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'],
                    style: Heading4.style.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  isTeam ? item['league'] : item['team'],
                  style: Body2.style.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
          if (isTeam && teamId != null)
            IconButton(
              tooltip: isFollowing ? 'Unfollow team' : 'Follow team',
              onPressed: () =>
                  currentUserPreferences.toggleFollowedTeam(teamId),
              icon: Icon(
                isFollowing ? Icons.star : Icons.star_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}
