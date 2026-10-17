import 'package:onetouch/models/profile_change_limit_exception.dart';
// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/core/app_close_header.dart';
import 'package:onetouch/core/app_snack_bar.dart';
import 'package:onetouch/core/app_rule_notice.dart';
import 'package:onetouch/core/app_search_field.dart';
import 'package:onetouch/core/search_text.dart';
import 'package:onetouch/core/app_scroll_edge_fade.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/following_teams_repository.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_page_eligibility_provider.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/features/team/team_name_with_favorite_star.dart';
import 'package:onetouch/features/competition/competition_label.dart';
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
  final String? shortName;
  final String? shortCode;
  final TeamCompetitionContext? competition;
  final String? imagePath;

  _TeamEntry({
    required this.teamId,
    required this.name,
    this.shortName,
    this.shortCode,
    required this.competition,
    this.imagePath,
  });
}

_TeamEntry _toEntry(Team t) => _TeamEntry(
      teamId: t.teamId,
      name: t.name,
      shortName: t.shortName,
      shortCode: t.shortCode,
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
  bool _showRuleNotice = true;

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
    final query = _searchController.text.trim();
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
            .where((t) => matchesSearchText(query, [
                  t.name,
                  t.shortName,
                  t.shortCode,
                  teamNameLabel(context, t.teamId, t.name),
                ]))
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

  Widget _buildFadingTeamList() => AppScrollEdgeFade(
        key: ValueKey(_searchController.text),
        topKey: const ValueKey('profile-team-edit-top-fade'),
        bottomKey: const ValueKey('profile-team-edit-bottom-fade'),
        child:
            _isSearching ? _buildSearchResultList() : _buildFollowedTeamList(),
      );

  void _removeTeam(int index) {
    if (_followedTeams.length == 1) {
      showAppSnackBar(
          context, tr(context, 'At least one team must stay followed.'));
      return;
    }
    setState(() {
      _followedTeams.removeAt(index);
      _favoriteTeamId = _followedTeams.first.teamId;
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
      showAppSnackBar(
          context, tr(context, 'At least one team must stay followed.'));
      return;
    }

    setState(() => _isSaving = true);

    final teamIds = candidateTeams.map((team) => team.teamId).toList();
    final favoriteTeamId = teamIds.first;

    try {
      final savedTeams = await widget.repository.replaceFollowing(
        teamIds: teamIds,
        favoriteTeamId: favoriteTeamId,
      );

      currentUserPreferences.applyServerSelection(UserTeamPreferences(
        favoriteTeamId: favoriteTeamId,
        followedTeamIds: savedTeams.map((team) => team.teamId).toList(),
      ));
      currentUserPreferences.resetViewedTeam();
      if (selectedTeam != null &&
          savedTeams.any((team) => team.teamId == selectedTeam.teamId)) {
        currentUserPreferences.viewTeam(selectedTeam.teamId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        FollowingTeamsEditResult(
          teams: savedTeams,
          favoriteTeamId: favoriteTeamId,
        ),
      );
    } on ProfileChangeLimitException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(
          context,
          profileChangeLimitMessage(context,
              item: tr(context, 'Primary team'), limit: error));
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showAppSnackBar(context,
          tr(context, 'Unable to update followed teams. Please try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: SizedBox(
          height: (constraints.maxHeight - keyboardInset) * 0.92,
          child: Container(
            key: const ValueKey('profile-team-edit-sheet'),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        AppCloseHeader(
                          title: tr(context, 'Following Teams'),
                          onClose: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(height: 12),

                        // Search bar
                        AppEditSearchField(
                          containerKey:
                              const ValueKey('profile-team-edit-search'),
                          controller: _searchController,
                          hintText: tr(context, 'Search teams to add!'),
                          searching: _isSearching,
                          verticalPadding: 16,
                          outerHorizontalPadding: 8,
                          clearIconSize: 20,
                        ),
                        // Team list (followed or search results)
                        Expanded(child: _buildFadingTeamList()),

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
                                      style: Body2.style.copyWith(
                                          color: appColors.mutedForeground),
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
                            onPressed: _updateEnabled && !_isSaving
                                ? _saveChanges
                                : null,
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                (states) =>
                                    states.contains(WidgetState.disabled)
                                        ? appColors.subtleBackground
                                        : colors.onSurface,
                              ),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                (states) =>
                                    states.contains(WidgetState.disabled)
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
                                    style: Body2_b.style
                                        .copyWith(color: colors.onPrimary),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                if (_showRuleNotice)
                  AppRuleNotice(
                    key: const ValueKey('team-edit-rule-notice'),
                    message: tr(context,
                        'You can change your favorite team up to twice in 14 days.'),
                    // 현재 편집 팝업에서만 숨기고, 다시 열면 표시해요.
                    onClose: () => setState(() => _showRuleNotice = false),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowedTeamList() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 24),
      itemCount: _followedTeams.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _followedTeams.removeAt(oldIndex);
          _followedTeams.insert(newIndex, item);
          _favoriteTeamId = _followedTeams.first.teamId;
          _updateEnabled = true;
        });
      },
      itemBuilder: (context, index) {
        final entry = _followedTeams[index];
        final isPrimary = entry.teamId == _favoriteTeamId;
        return Padding(
          key: ValueKey(entry.teamId),
          // 첫 로고의 위쪽 간격은 고정된 목록 위치가 담당해요.
          padding: EdgeInsets.only(
              top: index == 0 ? 0 : 8, bottom: index == 0 ? 16 : 8),
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
                      CompetitionLabel(
                        competitionId: entry.competition?.competitionId,
                        label: teamCompetitionLabel(context, entry.competition),
                        style: Eyebrow.style,
                        mainAxisAlignment: MainAxisAlignment.start,
                      ),
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

  Widget _buildSearchResultList() {
    if (_filteredTeams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            tr(context, "No teams found"),
            style: Body1.style.copyWith(
              color: AppColors.of(context).mutedForeground,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: 24),
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
        final competitionLabel =
            teamCompetitionLabel(context, team.competition);
        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('team-search-result-${team.teamId}'),
            onTap: alreadyFollowed ? null : () => _onSelectTeam(team),
            child: Padding(
              // 첫 로고는 고정된 목록 위치에 두고 남는 높이는 아래에 둬요.
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : 8,
                bottom: index == 0 ? 20 : 8,
              ),
              child: Row(
                children: [
                  SizedBox(
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          teamNameLabel(context, team.teamId, team.name),
                          style: Heading5.style,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (competitionLabel.isNotEmpty)
                          CompetitionLabel(
                            competitionId: team.competition?.competitionId,
                            label: competitionLabel,
                            style: Eyebrow.style,
                            mainAxisAlignment: MainAxisAlignment.start,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    isSelected || alreadyFollowed
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: alreadyFollowed
                        ? AppColors.of(context).mutedForeground
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
