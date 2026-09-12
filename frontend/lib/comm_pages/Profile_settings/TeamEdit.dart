import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_repository.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/team.dart';

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
      leagueLabel: teamCompetitionContextResolver.labelFor(t.teamId),
      imagePath: t.imagePath,
    );

class EditFollowingTeamsSheet extends StatefulWidget {
  const EditFollowingTeamsSheet({super.key});

  @override
  State<EditFollowingTeamsSheet> createState() =>
      _EditFollowingTeamsSheetState();
}

class _EditFollowingTeamsSheetState extends State<EditFollowingTeamsSheet> {
  final TextEditingController _searchController = TextEditingController();

  late List<_TeamEntry> _followedTeams;
  late List<_TeamEntry> _allTeams;
  int? _favoriteTeamId;

  List<_TeamEntry> _filteredTeams = [];
  _TeamEntry? _selectedTeam;
  _TeamEntry? _conflictTeam;
  bool _isSearching = false;
  bool _updateEnabled = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _favoriteTeamId = currentUserPreferences.favoriteTeamId.value;

    _followedTeams = currentUserPreferences.followedTeamIds.value
        .map((teamId) => teamRepository.requireById(teamId))
        .map(_toEntry)
        .toList();

    _allTeams = teamRepository.allTeams.map(_toEntry).toList();

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
    final newCompetitionId =
        teamCompetitionContextResolver.resolve(team.teamId)?.competitionId;
    _TeamEntry? conflict;
    if (newCompetitionId != null) {
      for (final t in _followedTeams) {
        if (teamCompetitionContextResolver.resolve(t.teamId)?.competitionId ==
                newCompetitionId &&
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

  void _removeTeam(int index) {
    if (_followedTeams.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one team must stay followed.')),
      );
      return;
    }
    setState(() {
      _followedTeams.removeAt(index);
      _updateEnabled = true;
    });
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final selectedTeam = _selectedTeam;
    if (selectedTeam != null &&
        !_followedTeams.any((team) => team.teamId == selectedTeam.teamId)) {
      if (_conflictTeam != null) {
        _followedTeams.removeWhere(
          (team) => team.teamId == _conflictTeam!.teamId,
        );
      }
      _followedTeams.add(selectedTeam);
    }

    final saved = await currentUserPreferences.updateFollowedTeams(
      _followedTeams.map((team) => team.teamId),
    );
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (context, scrollController) {
        return Container(
          key: const ValueKey('profile-team-edit-sheet'),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 48),
                  const Expanded(
                    child: Text(
                      "Following Teams",
                      style: Heading5.style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.onSurface),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search bar
              Container(
                key: const ValueKey('profile-team-edit-search'),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppPalette.lightGrey
                      : appColors.subtleBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  style: Body1.style,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                    hintText: "Search teams to add!",
                    hintStyle:
                        Body1.style.copyWith(color: appColors.mutedForeground),
                    border: InputBorder.none,
                    suffixIcon: _isSearching
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: colors.onSurface,
                              size: 20,
                            ),
                            onPressed: _searchController.clear,
                          )
                        : Icon(
                            Icons.search,
                            color: colors.onSurface,
                            size: 24,
                          ),
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
                      Icon(
                        Icons.info_outline,
                        color: appColors.mutedForeground,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: Body2.style
                                .copyWith(color: appColors.mutedForeground),
                            children: [
                              const TextSpan(
                                text:
                                    "You may select only one team from each league. "
                                    "This means you'd have to let go of ",
                              ),
                              TextSpan(
                                text: _conflictTeam!.name,
                                style: Body2_b.style
                                    .copyWith(color: colors.onSurface),
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
                  onPressed: _updateEnabled && !_isSaving ? _saveChanges : null,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? appColors.subtleBackground
                          : colors.onSurface,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) => states.contains(WidgetState.disabled)
                          ? appColors.mutedForeground
                          : colors.onPrimary,
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(vertical: 16),
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : Text(
                          "UPDATE",
                          style:
                              Body2_b.style.copyWith(color: colors.onPrimary),
                        ),
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
                onTap: () => _removeTeam(index),
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
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.shield,
                          color: AppColors.of(context).mutedForeground,
                          size: 40,
                        ),
                      )
                    : Icon(
                        Icons.shield,
                        color: AppColors.of(context).mutedForeground,
                        size: 40,
                      ),
              ),
              const SizedBox(width: 16),
              // Name + league label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.name,
                            style: Heading5.style,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.star,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 20,
                            ),
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
                child: Icon(
                  Icons.drag_handle,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: 32,
                ),
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
          style: Body1.style.copyWith(
            color: AppColors.of(context).mutedForeground,
          ),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: _filteredTeams.length,
      separatorBuilder: (_, __) => Divider(
        color: AppColors.of(context).divider,
        thickness: 1,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final team = _filteredTeams[index];
        final isSelected = _selectedTeam?.teamId == team.teamId;
        final alreadyFollowed =
            _followedTeams.any((entry) => entry.teamId == team.teamId);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: SizedBox(
            width: 52,
            height: 52,
            child: team.imagePath != null
                ? Image.network(
                    team.imagePath!,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.shield,
                      color: AppColors.of(context).mutedForeground,
                      size: 40,
                    ),
                  )
                : Icon(
                    Icons.shield,
                    color: AppColors.of(context).mutedForeground,
                    size: 40,
                  ),
          ),
          title: Text(
            team.name,
            style: Heading5.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: team.leagueLabel.isNotEmpty
              ? Text(
                  team.leagueLabel,
                  style: Eyebrow.style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
          trailing: GestureDetector(
            onTap: alreadyFollowed ? null : () => _onSelectTeam(team),
            child: Icon(
              isSelected || alreadyFollowed
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: alreadyFollowed
                  ? AppColors.of(context).mutedForeground
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      },
    );
  }
}
