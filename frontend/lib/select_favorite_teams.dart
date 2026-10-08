import 'dart:math' as math;
import 'dart:ui' show ImageFilter, lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/interactive_back_page.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/competitions/competition_repository_provider.dart';
import 'package:onetouch/data/catalog/football_catalog_provider.dart';
import 'package:onetouch/features/competition/competition_label.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/team.dart';
import 'rank_fav_teams.dart';
import 'welcome_loading_screen.dart';
import 'package:onetouch/l10n/app_localizations.dart';

class SelectFavoriteTeamsScreen extends StatefulWidget {
  const SelectFavoriteTeamsScreen({super.key, this.preferences});

  final CurrentUserPreferences? preferences;

  @override
  State<SelectFavoriteTeamsScreen> createState() =>
      _SelectFavoriteTeamsScreenState();
}

class _SelectFavoriteTeamsScreenState extends State<SelectFavoriteTeamsScreen> {
  late List<Competition> _leagues;
  late Map<int, List<Team>>
      _leagueTeams; // competitionId → teams sorted by standing

  late String selectedLeague;
  int get _selectedLeagueId =>
      _leagues.firstWhere((l) => l.name == selectedLeague).competitionId;

  final Map<int, Team> _selectedTeams = {};
  bool _isSaving = false;

  late final PageController _pageController;
  int _focusedIndex = 0;
  Team? _focusedTeam;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();

    _leagues = competitionRepository.domesticCompetitions
        .where((c) => footballCatalog.currentTeams(c.competitionId).isNotEmpty)
        .toList();

    _leagueTeams = {};
    for (final league in _leagues) {
      _leagueTeams[league.competitionId] =
          footballCatalog.currentTeams(league.competitionId);
    }

    selectedLeague = _leagues.first.name;
    _focusedTeam = _leagueTeams[_selectedLeagueId]?.firstOrNull;

    _pageController = PageController(viewportFraction: 0.6);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_isSaving || _selectedTeams.isEmpty) return;
    final teams = _selectedTeams.values.toList();
    if (teams.length > 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RankFavoriteTeamsScreen(selectedTeams: teams),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await (widget.preferences ?? currentUserPreferences)
          .updateTeamSelection([teams.single.teamId]);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeLoadingScreen()),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(context, 'Unable to save teams. Please try again.')),
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Team> get _currentTeams => _leagueTeams[_selectedLeagueId] ?? [];

  Gradient _gradientForFocusedTeam(BuildContext context) {
    final color = _focusedTeam != null
        ? Color(_focusedTeam!.primaryColor)
        : const Color(0xFF1F1F1F);
    final pageBackground = AppColors.of(context).pageBackground;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color, pageBackground],
    );
  }

  // --- OVERLAY LOGIC ---

  double _leagueDropdownMenuWidth(BuildContext context) {
    final style = Body2_b.style;
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var longestLabel = 0.0;
    for (final league in _leagues) {
      final painter = TextPainter(
        text: TextSpan(
          text: competitionNameLabel(
            context,
            league.competitionId,
            league.name,
          ).toUpperCase(),
          style: style,
        ),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      longestLabel = math.max(longestLabel, painter.width);
    }
    final triggerWidth = MediaQuery.sizeOf(context).width * 0.6;
    return math.max(triggerWidth, longestLabel + 80);
  }

  void _toggleDropdown() => _isDropdownOpen ? _removeOverlay() : _showOverlay();

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDropdownOpen = false);
  }

  void _showOverlay() {
    final dropdownWidth = _leagueDropdownMenuWidth(context);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final appColors = AppColors.of(context);
        return Stack(
          children: [
            GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              width: dropdownWidth,
              child: CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                offset: const Offset(0, AppDropdownTokens.height + 4),
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      key: const ValueKey('favorite-league-menu-blur'),
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _leagues.map((league) {
                            final isSelected = league.name == selectedLeague;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  selectedLeague = league.name;
                                  _focusedIndex = 0;
                                  _focusedTeam =
                                      _leagueTeams[league.competitionId]?.first;
                                });
                                if (_pageController.hasClients) {
                                  _pageController.jumpToPage(0);
                                }
                                _removeOverlay();
                              },
                              child: Padding(
                                padding: AppDropdownTokens.triggerPadding,
                                child: Row(
                                  children: [
                                    CompetitionLogo(
                                      competitionId: league.competitionId,
                                      size: 24,
                                      trailingGap: AppDropdownTokens.gap,
                                    ),
                                    Expanded(
                                      child: Text(
                                        competitionNameLabel(
                                                context,
                                                league.competitionId,
                                                league.name)
                                            .toUpperCase(),
                                        style: isSelected
                                            ? Body2_b.style.copyWith(
                                                fontWeight: FontWeight.bold)
                                            : Body2_b.style.copyWith(
                                                color:
                                                    appColors.mutedForeground),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final appColors = AppColors.of(context);
    final teams = _currentTeams;
    final focusedTeam =
        _focusedIndex < teams.length ? teams[_focusedIndex] : null;
    final isFocusedTeamSelected = focusedTeam != null &&
        _selectedTeams[_selectedLeagueId]?.teamId == focusedTeam.teamId;

    return Stack(
      children: [
        // 1) Animated background
        PopScope<void>(
          // iOS에서는 첫 팀을 벗어나면 캐러셀 드래그가 페이지 뒤로가기보다 먼저 동작해요.
          canPop: Theme.of(context).platform != TargetPlatform.iOS ||
              _focusedIndex == 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            decoration:
                BoxDecoration(gradient: _gradientForFocusedTeam(context)),
          ),
        ),

        // 2) Vignette
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    appColors.pageBackground.withValues(alpha: 0.85),
                    appColors.pageBackground,
                  ],
                  stops: [0.0, 0.40, 0.85, 1.0],
                ),
              ),
            ),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 원본 로고의 해상도가 낮을 수 있어 표시 크기를 150×150으로 제한해요.
                const logoSize = 150.0;
                final logoHeightScale =
                    ((constraints.maxHeight - 560) / 240).clamp(0.0, 1.0);
                // 작은 화면에서도 팀 로고의 150×150 영역을 유지해요.
                final carouselHeight =
                    math.max(logoSize, lerpDouble(112, 220, logoHeightScale)!);

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top bar
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SvgPicture.asset(
                                  'assets/app_logo.svg',
                                  key: const ValueKey('gradient-header-logo'),
                                  height: 23,
                                  width: 120,
                                  colorFilter: const ColorFilter.mode(
                                    AppPalette.white,
                                    BlendMode.srcIn,
                                  ),
                                  placeholderBuilder: (_) => const Text(
                                      "1TOUCH",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20)),
                                ),
                                AppThemeToggle(
                                  key: const ValueKey(
                                      'gradient-header-theme-toggle'),
                                  foregroundColor: AppPalette.white,
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Dropdown
                          _buildLeagueDropdown(),

                          const Spacer(flex: 1),

                          // Smooth-scrolling carousel
                          SizedBox(
                            key: const ValueKey('favorite-team-logo-region'),
                            height: carouselHeight,
                            child: PageView.builder(
                              controller: _pageController,
                              physics:
                                  InteractiveBackDragScope.isDragging(context)
                                      ? const NeverScrollableScrollPhysics()
                                      : null,
                              pageSnapping: true,
                              onPageChanged: (index) {
                                setState(() {
                                  _focusedIndex = index;
                                  _focusedTeam = teams[index];
                                });
                              },
                              itemCount: teams.length,
                              itemBuilder: (context, index) {
                                final team = teams[index];
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    setState(() {
                                      if (_selectedTeams[_selectedLeagueId]
                                              ?.teamId ==
                                          team.teamId) {
                                        _selectedTeams
                                            .remove(_selectedLeagueId);
                                      } else {
                                        _selectedTeams[_selectedLeagueId] =
                                            team;
                                      }
                                    });
                                  },
                                  child: Center(
                                    child: SizedBox.square(
                                      key: ValueKey(
                                          'favorite-team-logo-${team.teamId}'),
                                      dimension: logoSize,
                                      child: Image.network(
                                        team.imagePath ?? '',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield,
                                                color: Colors.white54,
                                                size: logoSize),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 10),

                          // Team name + checkmark
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 48),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    teamNameLabel(context, focusedTeam?.teamId,
                                        focusedTeam?.name ?? ''),
                                    style: Heading4.style,
                                    textAlign: TextAlign.center,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                AnimatedSize(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeInOut,
                                  child: isFocusedTeamSelected
                                      ? const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(width: 8),
                                            Icon(Icons.check_circle,
                                                color: Colors.blueAccent,
                                                size: 24),
                                          ],
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(flex: 2),

                          // Instruction text
                          Column(
                            children: [
                              Text(tr(context, "Select your favorite club(s)"),
                                  style: Heading5.style),
                              SizedBox(height: 6),
                              Text(
                                  tr(context,
                                      "You may choose up to 1 team per league"),
                                  style: Body2.style),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Selected team chips
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            constraints: const BoxConstraints(
                                minHeight: 50, maxHeight: 150),
                            child: _selectedTeams.isNotEmpty
                                ? SingleChildScrollView(
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 10,
                                      alignment: WrapAlignment.center,
                                      children:
                                          _selectedTeams.values.map((team) {
                                        return Container(
                                          key: ValueKey(
                                              'selected-team-${team.teamId}'),
                                          constraints: BoxConstraints(
                                            maxWidth: MediaQuery.sizeOf(context)
                                                    .width -
                                                48,
                                          ),
                                          padding: const EdgeInsets.fromLTRB(
                                              16, 8, 8, 8),
                                          decoration: BoxDecoration(
                                            color: appColors.cardBackground,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  teamNameLabel(context,
                                                      team.teamId, team.name),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: Body2_b.style.copyWith(
                                                      color: colors.onSurface),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedTeams.removeWhere(
                                                        (_, v) =>
                                                            v.teamId ==
                                                            team.teamId);
                                                  });
                                                },
                                                child: const Icon(Icons.close,
                                                    size: 24),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  )
                                : const SizedBox(height: 50),
                          ),

                          const SizedBox(height: 20),

                          // Continue button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: ElevatedButton(
                              key: const ValueKey('select-favorites-continue'),
                              onPressed: _selectedTeams.isEmpty || _isSaving
                                  ? null
                                  : _continue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.onSurface,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                disabledBackgroundColor:
                                    appColors.subtleBackground,
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
                                  : Text(trUpper(context, "Continue"),
                                      style: Body2_b.style
                                          .copyWith(color: colors.surface)),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueDropdown() {
    final league = _leagues.firstWhere((l) => l.name == selectedLeague);
    final onBrand = AppColors.of(context).onBrand;
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
          child: BackdropFilter(
            key: const ValueKey('favorite-league-trigger-blur'),
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.6,
              height: AppDropdownTokens.height,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDropdownTokens.radius),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 16,
                    right: 40,
                    top: 8,
                    bottom: 8,
                    child: Row(
                      children: [
                        CompetitionLogo(
                          competitionId: league.competitionId,
                          size: 24,
                          trailingGap: 8,
                        ),
                        Expanded(
                          child: Text(
                            competitionNameLabel(context, league.competitionId,
                                    selectedLeague)
                                .toUpperCase(),
                            style: Body2_b.style.copyWith(color: onBrand),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: AppDropdownChevron(
                      expanded: _isDropdownOpen,
                      color: onBrand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
