import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/features/team/team_name_with_favorite_star.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class FollowingTeamsEditResult {
  const FollowingTeamsEditResult({
    required this.teams,
    required this.favoriteTeamId,
  });

  final List<Team> teams;
  final int favoriteTeamId;
}

class _TeamEntry {
  final int teamId;
  final String name;
  final TeamCompetitionContext? competition;
  final String? imagePath;

  _TeamEntry({
    required this.teamId,
    required this.name,
    required this.competition,
    this.imagePath,
  });
}

_TeamEntry _toEntry(Team t) => _TeamEntry(
      teamId: t.teamId,
      name: t.name,
      competition: teamCompetitionContextResolver.resolve(t.teamId),
      imagePath: t.imagePath,
    );

class EditFollowingTeamsSheet extends StatefulWidget {
  const EditFollowingTeamsSheet({
    super.key,
    required this.repository,
    required this.initialTeams,
    required this.initialFavoriteTeamId,
  });

  final FollowingTeamsRepository repository;
  final List<Team> initialTeams;
  final int initialFavoriteTeamId;

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
    _followedTeams = widget.initialTeams
        .where((team) => teamPageEligibility.supports(team.teamId))
        .map(_toEntry)
        .toList();
    _favoriteTeamId = _followedTeams.any(
      (team) => team.teamId == widget.initialFavoriteTeamId,
    )
        ? widget.initialFavoriteTeamId
        : _followedTeams.firstOrNull?.teamId;

    _allTeams = teamRepository.allTeams
        .where((team) => teamPageEligibility.supports(team.teamId))
        .map(_toEntry)
        .toList();

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
            .where((t) =>
                t.name.toLowerCase().contains(query) ||
                teamNameLabel(context, t.teamId, t.name)
                    .toLowerCase()
                    .contains(query))
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
        SnackBar(
            content:
                Text(tr(context, 'At least one team must stay followed.'))),
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

    final candidateTeams = List<_TeamEntry>.of(_followedTeams);
    final selectedTeam = _selectedTeam;
    if (selectedTeam != null &&
        !candidateTeams.any((team) => team.teamId == selectedTeam.teamId)) {
      if (_conflictTeam != null) {
        candidateTeams.removeWhere(
          (team) => team.teamId == _conflictTeam!.teamId,
        );
      }
      candidateTeams.add(selectedTeam);
    }

    if (candidateTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(tr(context, 'At least one team must stay followed.'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final teamIds = candidateTeams.map((team) => team.teamId).toList();
    final favoriteTeamId =
        teamIds.contains(_favoriteTeamId) ? _favoriteTeamId! : teamIds.first;

    try {
      final savedTeams = await widget.repository.replaceFollowing(
        teamIds: teamIds,
        favoriteTeamId: favoriteTeamId,
      );

      currentUserPreferences.applyServerSelection(UserTeamPreferences(
        favoriteTeamId: favoriteTeamId,
        followedTeamIds: savedTeams.map((team) => team.teamId).toList(),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(
        FollowingTeamsEditResult(
          teams: savedTeams,
          favoriteTeamId: favoriteTeamId,
        ),
      );
    } on FavoriteTeamCooldownException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
              context, 'Unable to update followed teams. Please try again.')),
        ),
      );
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
                  Expanded(
                    child: Text(
                      tr(context, "Following Teams"),
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
                    hintText: tr(context, "Search teams to add!"),
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
                            text: tr(
                                context,
                                'You can follow one team per league. Following this team will replace {team}. Continue?',
                                {
                                  'team': teamNameLabel(
                                      context,
                                      _conflictTeam!.teamId,
                                      _conflictTeam!.name)
                                }),
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
                          tr(context, "UPDATE"),
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
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
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
                    TeamNameWithFavoriteStar(
                      teamId: entry.teamId,
                      name: entry.name,
                      isFavorite: isPrimary,
                      style: Heading5.style,
                    ),
                    if (teamCompetitionLabel(context, entry.competition)
                        .isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(teamCompetitionLabel(context, entry.competition),
                          style: Eyebrow.style),
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
          tr(context, "No teams found"),
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
            teamNameLabel(context, team.teamId, team.name),
            style: Heading5.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: teamCompetitionLabel(context, team.competition).isNotEmpty
              ? Text(
                  teamCompetitionLabel(context, team.competition),
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
