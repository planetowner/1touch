import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class EditFollowingTeamsSheet extends StatefulWidget {
  const EditFollowingTeamsSheet({super.key});

  @override
  State<EditFollowingTeamsSheet> createState() => _EditFollowingTeamsSheetState();
}

class _EditFollowingTeamsSheetState extends State<EditFollowingTeamsSheet> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, String>> allTeams = [
    {"name": "FC Barcelona", "league": "La Liga 1st", "logo": "TeamLogos/Barcelona.png"},
    {"name": "Bayern Munich", "league": "Bundesliga 1st", "logo": "TeamLogos/Barcelona.png"},
    {"name": "Everton", "league": "PL 13th", "logo": "TeamLogos/Barcelona.png"},
    {"name": "Eintracht Frankfurt", "league": "Bundesliga 3rd", "logo": "TeamLogos/Barcelona.png"},
  ];

  List<Map<String, String>> followedTeams = [];
  List<Map<String, String>> filteredTeams = [];
  String? selectedTeamName;
  bool updateEnabled = false;
  String? leagueToReplace;
  bool isSearching = false;

  @override
  void initState() {
    super.initState();
    followedTeams = List.from(allTeams); // mock initial followed list
    filteredTeams = allTeams;

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        setState(() {
          isSearching = true;
          filteredTeams = allTeams.where((team) => team['name']!.toLowerCase().startsWith(query)).toList();
        });
      } else {
        setState(() {
          isSearching = false;
          selectedTeamName = null;
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
            color: Color(0xFF272828),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 32),
                  const Text("Following Teams", style: Heading5.style),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search teams to add!",
                    hintStyle: Body1.style.copyWith(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: Icon(Icons.search, color: Colors.white, size: 24),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              isSearching
                  ? _buildSearchResultList(scrollController)
                  : _buildFollowedTeamList(scrollController),

              if (isSearching && selectedTeamName != null && leagueToReplace != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You may select only one team from each league. This means you'd have to let go of $leagueToReplace. Are you sure you want to proceed?",
                          style: Body2.style,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: updateEnabled ? () => Navigator.of(context).pop() : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                    states.contains(WidgetState.disabled) ? Colors.grey.shade700 : Colors.white),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) =>
                    states.contains(WidgetState.disabled) ? Colors.grey.shade400 : Colors.black),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  child: Text("UPDATE", style: Body2_b.style.copyWith(color: Colors.black)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowedTeamList(ScrollController controller) {
    return SingleChildScrollView(
      controller: controller,
      child: Column(
        children: followedTeams.map((team) => buildFollowingTeamItem(
          teamName: team['name']!,
          league: team['league']!,
          logoPath: team['logo']!,
          isPrimary: team['name'] == "FC Barcelona",
          onRemove: () {},
        )).toList(),
      ),
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    return Expanded(
      child: ListView.builder(
        controller: controller,
        itemCount: filteredTeams.length,
        itemBuilder: (context, index) {
          final team = filteredTeams[index];
          final isSelected = selectedTeamName == team['name'];

          return Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Image.asset(team['logo']!, width: 52, height: 52),
                title: Text(team['name']!, style: Heading5.style),
                subtitle: Text(team['league']!, style: Eyebrow.style),
                trailing: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedTeamName = team['name'];
                      updateEnabled = true;
                      if (team['league']!.startsWith("PL")) {
                        leagueToReplace = "Man City";
                      } else {
                        leagueToReplace = null;
                      }
                    });
                  },
                  child: Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: Colors.white,
                  ),
                ),
              ),
              const Divider(color: Color(0xFF3D3D3D), thickness: 1, height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget buildFollowingTeamItem({
    required String teamName,
    required String league,
    required String logoPath,
    required VoidCallback onRemove,
    required bool isPrimary,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              backgroundColor: Color(0xFFF54E5C),
              radius: 10,
              child: Icon(Icons.remove, size: 20, color: Colors.black),
            ),
          ),
          const SizedBox(width: 16),
          Image.asset(logoPath, width: 52, height: 52),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(teamName, style: Heading5.style),
                    if (isPrimary)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.star, color: Colors.white, size: 20),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(league, style: Eyebrow.style),
              ],
            ),
          ),
          const Icon(Icons.drag_handle, color: Colors.white, size: 32),
        ],
      ),
    );
  }
}
