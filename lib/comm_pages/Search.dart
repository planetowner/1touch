import "package:flutter/material.dart";
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/stylesheet_dark.dart';


class Search extends StatelessWidget {
  const Search({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Transparent for gradient effect
      body: SafeArea(
        child: Stack(
          children: [
            // Gradient background
            AnimatedOpacity(
              opacity: 1.0,
              // Or adjust based on scroll if you need dynamic opacity
              duration: Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99B40000), // Deep Red
                      Color(0x00B40000), // Transparent
                    ],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
            const SearchContent(), // Your search content
          ],
        ),
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
  final TextEditingController _controller = TextEditingController();
  String query = "";
  bool searchActive = false;
  final List<Map<String, dynamic>> searchResults = [
    {
      "type": "player",
      "name": "Bradley Barcola",
      "team": "Paris Saint-Germain",
      "number": "29",
      "image": "assets/player.png"
    },
    {
      "type": "team",
      "name": "FC Barcelona",
      "rank": "LaLiga 1st",
      "logo": "assets/barca_logo.svg",
      "isFavorite": true
    },
    {
      "type": "event",
      "homeTeam": "FCB",
      "awayTeam": "GRN",
      "homeLogo": "assets/barca_logo.svg",
      "awayLogo": "assets/girona_logo.svg",
      "date": "Sun, Sep 15",
      "time": "10:15 AM"
    },
  ];

  final List<String> filters = ['ALL', 'PLAYERS', 'TEAMS', 'EVENTS'];
  int selectedFilter = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(context),
        if (searchActive) ...[
          _buildFilterChips(),
          const SizedBox(height: 8),
          Expanded(child: _buildSearchResults()),
        ] else ...[
          Expanded(child: _buildRecentResults()),
        ],
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 47, 24, 24),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: TextField(
              onTap: () {
                if (!searchActive) {
                  setState(() => searchActive = true);
                }
              },
              controller: _controller,
              onChanged: (text) => setState(() => query = text),
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: "Search",
                hintStyle: const TextStyle(color: Colors.black),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    _controller.clear();
                    setState(() => query = "");
                  },
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(filters.length, (index) {
          bool isSelected = selectedFilter == index;
          return ChoiceChip(
            label: Text(
              filters[index],
              style: TextStyle(
                  color: isSelected ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
            selected: isSelected,
            onSelected: (_) => setState(() => selectedFilter = index),
            selectedColor: Colors.white,
            backgroundColor: Color(0xFF3D3D3D),
            side: BorderSide.none,
            shape: StadiumBorder(),
            showCheckmark: false,
          );
        }),
      ),
    );
  }

  Widget _buildSearchResults() {
    // You’ll replace this with dynamic results based on `query` and `selectedFilter`
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];

        switch (result["type"]) {
          case "player":
            return _buildPlayerCard(result);
          case "team":
            return _buildTeamCard(result);
          case "event":
            return _buildMatchCard(result);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildRecentResults() {
    final recent = ["FC Barcelona", "Erling Haaland", "PSG"];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: recent.length,
      itemBuilder: (_, index) {
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF272828),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                recent[index],
                style: Heading5.style
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildPlayerCard(Map result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.grey[800],
                backgroundImage: AssetImage(result['image'] ?? 'assets/placeholder.png'),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  result['number'] ?? '##',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result['name'], style: Heading5.style),
              const SizedBox(height: 4),
              Text(result['team'], style: Body2.style),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Image.asset(result['logo'], fit: BoxFit.contain),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['name'], style: Heading5.style),
                const SizedBox(height: 4),
                Text(result['rank'], style: Body2.style),
              ],
            ),
          ),
          const Icon(Icons.star, color: Colors.white, size: 20),
        ],
      ),
    );
  }

  Widget _buildMatchCard(Map result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Image.asset(result['homeLogo'], fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Text(result['homeTeam'], style: Body2.style),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text("#", style: Heading3.style),
          ),
          Column(
            children: [
              Text(result['date'], style: Body2.style),
              const SizedBox(height: 4),
              Text(result['time'], style: Body2.style),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text("#", style: Heading3.style),
          ),
          Column(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: Image.asset(result['awayLogo'], fit: BoxFit.contain),
              ),
              const SizedBox(height: 6),
              Text(result['awayTeam'], style: Body2.style),
            ],
          ),
        ],
      ),
    );
  }
}
