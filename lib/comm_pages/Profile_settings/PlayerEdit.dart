import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
// If players have SVG logos/faces, keep this. If network images, we'll use Image.network
// import 'package:flutter_svg/flutter_svg.dart';

class EditFollowingPlayersSheet extends StatefulWidget {
  const EditFollowingPlayersSheet({super.key});

  @override
  State<EditFollowingPlayersSheet> createState() => _EditFollowingPlayersSheetState();
}

class _EditFollowingPlayersSheetState extends State<EditFollowingPlayersSheet> {
  final TextEditingController _searchController = TextEditingController();

  // Mock Data: All available players
  List<Map<String, String>> allPlayers = [
    {
      "name": "Lionel Messi",
      "team": "Inter Miami",
      "number": "10",
      "image": "https://placehold.co/64x64/png", // Placeholder for network image
    },
    {
      "name": "Erling Haaland",
      "team": "Manchester City",
      "number": "9",
      "image": "https://placehold.co/64x64/png",
    },
    {
      "name": "Kylian Mbappé",
      "team": "Real Madrid",
      "number": "9",
      "image": "https://placehold.co/64x64/png",
    },
    {
      "name": "Son Heung-min",
      "team": "Tottenham",
      "number": "7",
      "image": "https://placehold.co/64x64/png",
    },
  ];

  List<Map<String, String>> followedPlayers = [];
  List<Map<String, String>> filteredPlayers = [];

  // Selection State
  String? selectedPlayerName;
  bool updateEnabled = false;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    // Initialize followed players with some mock data or empty
    followedPlayers = List.from(allPlayers);
    filteredPlayers = allPlayers;

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        setState(() {
          isSearching = true;
          selectedPlayerName = null;
          updateEnabled = false;
          filteredPlayers = allPlayers
              .where((player) => player['name']!.toLowerCase().startsWith(query))
              .toList();
        });
      } else {
        setState(() {
          isSearching = false;
          selectedPlayerName = null;
          updateEnabled = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF272828), // Dark Grey Background matches TeamEdit
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const Text("Following Players", style: Heading5.style),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  cursorColor: Colors.white,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    hintText: "Search players to add!",
                    hintStyle: Body1.style.copyWith(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: const Icon(Icons.search, color: Colors.white, size: 24),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 3. List View
              isSearching
                  ? _buildSearchResultList(scrollController)
                  : _buildFollowedPlayerList(scrollController),

              const SizedBox(height: 16),

              // 4. Update Button
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: updateEnabled ? () => Navigator.of(context).pop() : null,
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                      states.contains(WidgetState.disabled) ? Colors.grey.shade800 : Colors.white),
                      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                      states.contains(WidgetState.disabled) ? Colors.grey.shade500 : Colors.black),
                      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 16)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    child: Text("UPDATE", style: Body2_b.style),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- Widgets ---

  Widget _buildFollowedPlayerList(ScrollController controller) {
    return Expanded(
      child: SingleChildScrollView(
        controller: controller,
        child: Column(
          children: followedPlayers.map((player) => _buildPlayerItem(
            name: player['name']!,
            team: player['team']!,
            number: player['number']!,
            imageUrl: player['image']!,
            onRemove: () {
              // Handle remove logic
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    return Expanded(
      child: ListView.builder(
        controller: controller,
        itemCount: filteredPlayers.length,
        itemBuilder: (context, index) {
          final player = filteredPlayers[index];
          final isSelected = selectedPlayerName == player['name'];

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                // Using CircleAvatar for player face
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(player['image']!),
                  backgroundColor: Colors.grey[800],
                  radius: 24,
                ),
                title: Text(player['name']!, style: Heading5.style),
                subtitle: Text("${player['team']} • #${player['number']}", style: Eyebrow.style),
                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedPlayerName = player['name'];
                      updateEnabled = true;
                      // No restriction logic here
                    });
                  },
                  child: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xFFD82457) : Colors.white54,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF3A3A3A), thickness: 1, height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlayerItem({
    required String name,
    required String team,
    required String number,
    required String imageUrl,
    required VoidCallback onRemove,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF54E5C),
              radius: 12,
              child: Icon(Icons.remove, size: 18, color: Colors.black),
            ),
          ),
          const SizedBox(width: 16),

          // Player Image
          CircleAvatar(
            backgroundImage: NetworkImage(imageUrl),
            backgroundColor: Colors.grey[800],
            radius: 24,
          ),

          const SizedBox(width: 16),

          // Player Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: Heading5.style),
                const SizedBox(height: 4),
                Text("$team • #$number", style: Eyebrow.style),
              ],
            ),
          ),

          // Drag Handle
          const Icon(Icons.drag_handle, color: Colors.white54, size: 28),
        ],
      ),
    );
  }
}