import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/team.dart';

const _domesticLeagueIds = {8, 82, 301, 384, 564};

int? _leagueIdForTeam(int teamId) => mockStandings
    .where((s) => s.teamId == teamId && _domesticLeagueIds.contains(s.leagueId))
    .firstOrNull
    ?.leagueId;

class _TeamEntry {
  final int teamId;
  final String name;
  final String leagueLabel;
  final String? imagePath;

  _TeamEntry({
    required this.teamId,
    required this.name,
    required this.leagueLabel,
    this.imagePath,
  });
}

_TeamEntry _toEntry(Team t) => _TeamEntry(
      teamId: t.teamId,
      name: t.name,
      leagueLabel: teamLeagueLabel(t.teamId),
      imagePath: t.imagePath,
    );

class EditFollowingTeamsSheet extends StatefulWidget {
  const EditFollowingTeamsSheet({super.key});

  @override
  State<EditFollowingTeamsSheet> createState() =>
      _EditFollowingTeamsSheetState();
}

class _EditFollowingTeamsSheetState extends State<EditFollowingTeamsSheet> {
  static const _currentUserId = 1001;

  final TextEditingController _searchController = TextEditingController();

  late List<_TeamEntry> _followedTeams;
  late List<_TeamEntry> _allTeams;
  int? _favoriteTeamId;

  List<_TeamEntry> _filteredTeams = [];
  _TeamEntry? _selectedTeam;
  _TeamEntry? _conflictTeam;
  bool _isSearching = false;
  bool _updateEnabled = false;

  @override
  void initState() {
    super.initState();
    _favoriteTeamId = mockUserProfileById(_currentUserId).favoriteTeamId;

    _followedTeams = followingTeamIds(_currentUserId)
        .map((id) => _toEntry(mockTeamById(id)))
        .toList();

    _allTeams = mockTeams.map(_toEntry).toList();

    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _selectedTeam = null;
        _conflictTeam = null;
      });
    } else {
      setState(() {
        _isSearching = true;
        _filteredTeams = _allTeams
            .where((t) => t.name.toLowerCase().contains(query))
            .toList();
        _selectedTeam = null;
        _conflictTeam = null;
      });
    }
  }

  void _onSelectTeam(_TeamEntry team) {
    final newLeagueId = _leagueIdForTeam(team.teamId);
    _TeamEntry? conflict;
    if (newLeagueId != null) {
      for (final t in _followedTeams) {
        if (_leagueIdForTeam(t.teamId) == newLeagueId &&
            t.teamId != team.teamId) {
          conflict = t;
          break;
        }
      }
    }
    setState(() {
      _selectedTeam = team;
      _conflictTeam = conflict;
      _updateEnabled = true;
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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
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
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 8),
                    hintText: "Search teams to add!",
                    hintStyle: Body1.style.copyWith(color: Colors.white54),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 20),
                            onPressed: _searchController.clear,
                          )
                        : const Icon(Icons.search,
                            color: Colors.white, size: 24),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Team list (followed or search results)
              Expanded(
                child: _isSearching
                    ? _buildSearchResultList(scrollController)
                    : _buildFollowedTeamList(scrollController),
              ),

              // Conflict warning
              if (_isSearching &&
                  _selectedTeam != null &&
                  _conflictTeam != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Body2.style.copyWith(color: Colors.white70),
                            children: [
                              const TextSpan(
                                text:
                                    "You may select only one team from each league. "
                                    "This means you'd have to let go of ",
                              ),
                              TextSpan(
                                text: _conflictTeam!.name,
                                style:
                                    Body2_b.style.copyWith(color: Colors.white),
                              ),
                              const TextSpan(
                                  text: ". Are you sure you want to proceed?"),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // UPDATE button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _updateEnabled ? () => Navigator.of(context).pop() : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.grey.shade700
                          : Colors.white,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? Colors.grey.shade400
                          : Colors.black,
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  child: Text("UPDATE",
                      style: Body2_b.style.copyWith(color: Colors.black)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFollowedTeamList(ScrollController controller) {
    return ReorderableListView.builder(
      scrollController: controller,
      itemCount: _followedTeams.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _followedTeams.removeAt(oldIndex);
          _followedTeams.insert(newIndex, item);
          _updateEnabled = true;
        });
      },
      itemBuilder: (context, index) {
        final entry = _followedTeams[index];
        final isPrimary = entry.teamId == _favoriteTeamId;
        return Padding(
          key: ValueKey(entry.teamId),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              // Remove button
              GestureDetector(
                onTap: () => setState(() {
                  _followedTeams.removeAt(index);
                  _updateEnabled = true;
                }),
                child: const CircleAvatar(
                  backgroundColor: Color(0xFFF54E5C),
                  radius: 10,
                  child: Icon(Icons.remove, size: 20, color: Colors.black),
                ),
              ),
              const SizedBox(width: 16),
              // Team logo
              SizedBox(
                width: 52,
                height: 52,
                child: entry.imagePath != null
                    ? Image.network(
                        entry.imagePath!,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.shield,
                            color: Colors.white38,
                            size: 40),
                      )
                    : const Icon(Icons.shield,
                        color: Colors.white38, size: 40),
              ),
              const SizedBox(width: 16),
              // Name + league label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.name, style: Heading5.style),
                        if (isPrimary)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child:
                                Icon(Icons.star, color: Colors.white, size: 20),
                          ),
                      ],
                    ),
                    if (entry.leagueLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(entry.leagueLabel, style: Eyebrow.style),
                    ],
                  ],
                ),
              ),
              // Drag handle
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle,
                    color: Colors.white, size: 32),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResultList(ScrollController controller) {
    if (_filteredTeams.isEmpty) {
      return Center(
        child: Text(
          "No teams found",
          style: Body1.style.copyWith(color: Colors.white54),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _filteredTeams.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Color(0xFF3D3D3D), thickness: 1, height: 1),
      itemBuilder: (context, index) {
        final team = _filteredTeams[index];
        final isSelected = _selectedTeam?.teamId == team.teamId;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 52,
            height: 52,
            child: team.imagePath != null
                ? Image.network(
                    team.imagePath!,
                    errorBuilder: (_, __, ___) => const Icon(Icons.shield,
                        color: Colors.white38, size: 40),
                  )
                : const Icon(Icons.shield, color: Colors.white38, size: 40),
          ),
          title: Text(team.name, style: Heading5.style),
          subtitle: team.leagueLabel.isNotEmpty
              ? Text(team.leagueLabel, style: Eyebrow.style)
              : null,
          trailing: GestureDetector(
            onTap: () => _onSelectTeam(team),
            child: Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}