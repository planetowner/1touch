import 'package:flutter/material.dart';
import 'package:onetouch/WelcomeLoadingScreen.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/teams/team_competition_context.dart';
import 'package:onetouch/data/teams/team_repository_provider.dart';
import 'package:onetouch/models/team.dart';

class RankFavoriteTeamsScreen extends StatefulWidget {
  final List<Team> selectedTeams;

  const RankFavoriteTeamsScreen({super.key, required this.selectedTeams});

  @override
  State<RankFavoriteTeamsScreen> createState() =>
      _RankFavoriteTeamsScreenState();
}

class _RankFavoriteTeamsScreenState extends State<RankFavoriteTeamsScreen> {
  late List<Team> _myTeams;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _myTeams = List.from(widget.selectedTeams);
  }

  String _leagueSubtitle(Team team) =>
      teamCompetitionContextResolver.labelFor(team.teamId);

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final team = _myTeams.removeAt(oldIndex);
      _myTeams.insert(newIndex, team);
    });
  }

  Future<void> _completeOnboarding() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    await currentUserPreferences.updateTeamSelection(
      _myTeams.map((team) => team.teamId),
    );
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeLoadingScreen()),
    );
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pageBackground = AppColors.of(context).pageBackground;
    final gradientHeight = responsiveBrandGradientHeight(context);

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            key: const ValueKey('rank-favorites-background'),
            color: pageBackground,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: gradientHeight,
          child: DecoratedBox(
            key: const ValueKey('rank-favorites-top-gradient'),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppPalette.lightGrey,
                  AppPalette.lightGrey.withValues(alpha: 0.72),
                  Colors.transparent,
                ],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        key: const ValueKey('rank-favorites-back-button'),
                        tooltip: 'Back to team selection',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppPalette.white,
                        ),
                      ),
                      const AppThemeToggle(
                        key: ValueKey('gradient-header-theme-toggle'),
                        foregroundColor: AppPalette.white,
                      ),
                    ],
                  ),
                ),

                // Draggable list
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const cardHeight = 72.0;
                      final teamCount = _myTeams.length;
                      final verticalGap = teamCount == 0
                          ? 20.0
                          : ((constraints.maxHeight - cardHeight * teamCount) /
                                  (teamCount + 1))
                              .clamp(4.0, 20.0)
                              .toDouble();

                      return ReorderableListView(
                        key: const ValueKey('rank-team-list'),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: verticalGap,
                        ),
                        onReorderItem: _onReorder,
                        proxyDecorator: (child, index, animation) => Material(
                          color: Colors.transparent,
                          elevation: 12,
                          shadowColor: Colors.black54,
                          child: Transform.scale(scale: 1.03, child: child),
                        ),
                        children: [
                          for (int i = 0; i < _myTeams.length; i++)
                            _buildTeamCard(
                              i,
                              _myTeams[i],
                              cardHeight,
                              verticalGap,
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      const Text("Rank your clubs", style: Heading4.style),
                      const SizedBox(height: 8),
                      Text(
                        "Hold and drag a team card up or down to reorder your favorites. Don't worry, you can always change this later.",
                        textAlign: TextAlign.center,
                        style: Body2.style,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.onSurface,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.surface,
                                ),
                              )
                            : Text("CONTINUE",
                                style: Body2_b.style
                                    .copyWith(color: colors.surface)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(
    int index,
    Team team,
    double cardHeight,
    double verticalGap,
  ) {
    final colors = Theme.of(context).colorScheme;
    final onBrand = AppColors.of(context).onBrand;
    final isFirst = index == 0;
    final primaryColor = Color(team.primaryColor);
    final darkerColor = Color.lerp(primaryColor, Colors.black, 0.55)!;
    final subtitle = _leagueSubtitle(team);

    return Container(
      key: ValueKey(team.teamId),
      margin: EdgeInsets.only(
        bottom: index == _myTeams.length - 1 ? 0 : verticalGap,
      ),
      child: Row(
        children: [
          // Rank indicator — outside the card, left
          SizedBox(
            width: 32,
            child: Center(
              child: isFirst
                  ? Icon(Icons.star, color: colors.onSurface, size: 18)
                  : Text('${index + 1}',
                      style: Heading5.style.copyWith(color: colors.onSurface)),
            ),
          ),
          const SizedBox(width: 8),
          // Card
          Expanded(
            child: SizedBox(
              key: ValueKey('rank-team-card-${team.teamId}'),
              height: cardHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [primaryColor, darkerColor],
                  ),
                  border: isFirst
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.5)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Logo watermark — right side
                      if (team.imagePath != null)
                        Positioned(
                          right: -cardHeight * 0.2,
                          top: -cardHeight * 0.65,
                          child: Opacity(
                            opacity: 0.35,
                            child: SizedBox(
                              key: ValueKey('rank-team-logo-${team.teamId}'),
                              width: cardHeight * 2.3,
                              height: cardHeight * 2.3,
                              child: Image.network(
                                team.imagePath!,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          ),
                        ),
                      // Team name + league — left side
                      Positioned(
                        left: 16,
                        right: 64,
                        top: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              team.name,
                              key: ValueKey('rank-team-name-${team.teamId}'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Heading5.style.copyWith(
                                color: AppPalette.white,
                              ),
                            ),
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                key: ValueKey(
                                  'rank-team-position-${team.teamId}',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Body2.style.copyWith(
                                  fontSize: 12,
                                  color: AppPalette.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Drag handle — far right
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: ReorderableDragStartListener(
                          index: index,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            color: Colors.transparent,
                            child: Center(
                              child: Icon(
                                Icons.drag_handle_rounded,
                                color: onBrand.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
