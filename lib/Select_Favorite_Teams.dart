import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/core/theme_controller.dart';
import 'package:onetouch/data/competitions/mock/competition_catalog.dart';
import 'package:onetouch/data/competitions/mock/standing_catalog.dart';
import 'package:onetouch/data/teams/mock/team_catalog.dart';
import 'package:onetouch/features/helper.dart';
import 'package:onetouch/models/competition.dart';
import 'package:onetouch/models/team.dart';
import 'RankFavTeams.dart';

const _domesticLeagueIds = {8, 82, 301, 384, 564};

class SelectFavoriteTeamsScreen extends StatefulWidget {
  const SelectFavoriteTeamsScreen({super.key});

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

  late final PageController _pageController;
  int _focusedIndex = 0;
  Team? _focusedTeam;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();

    _leagues = mockCompetitions
        .where((l) => _domesticLeagueIds.contains(l.competitionId))
        .toList();

    _leagueTeams = {};
    for (final league in _leagues) {
      final standingsForLeague = mockStandings
          .where((s) => s.competitionId == league.competitionId)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      _leagueTeams[league.competitionId] =
          standingsForLeague.map((s) => mockTeamById(s.teamId)).toList();
    }

    selectedLeague = _leagues.first.name;
    _focusedTeam = _leagueTeams[_selectedLeagueId]?.first;

    _pageController = PageController(viewportFraction: 0.6);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _pageController.dispose();
    super.dispose();
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

  void _toggleDropdown() => _isDropdownOpen ? _removeOverlay() : _showOverlay();

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDropdownOpen = false);
  }

  void _showOverlay() {
    final dropdownWidth = MediaQuery.of(context).size.width * 0.6;

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
                offset: Offset.zero,
                child: Material(
                  color: Colors.transparent,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              appColors.cardBackground.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2)),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Image.network(
                                      league.imagePath ?? '',
                                      width: 24,
                                      height: 24,
                                      errorBuilder: (_, __, ___) =>
                                          competitionLogoFallback(
                                              league.competitionId,
                                              size: 24),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        league.name,
                                        style: isSelected
                                            ? Heading5.style.copyWith(
                                                fontWeight: FontWeight.bold)
                                            : Heading5.style.copyWith(
                                                color:
                                                    appColors.mutedForeground),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.keyboard_arrow_up,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          size: 20),
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(gradient: _gradientForFocusedTeam(context)),
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
                final heightScale =
                    ((constraints.maxHeight - 560) / 240).clamp(0.0, 1.0);
                final topBarPadding = lerpDouble(20, 30, heightScale)!;
                final topGap = lerpDouble(8, 20, heightScale)!;
                final carouselHeight = lerpDouble(180, 220, heightScale)!;
                final bottomGap = lerpDouble(16, 32, heightScale)!;

                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // Top bar
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: topBarPadding,
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

                          SizedBox(height: topGap),

                          // Dropdown
                          _buildLeagueDropdown(),

                          const Spacer(flex: 1),

                          // Smooth-scrolling carousel
                          SizedBox(
                            height: carouselHeight,
                            child: PageView.builder(
                              controller: _pageController,
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
                                return AnimatedBuilder(
                                  animation: _pageController,
                                  builder: (context, child) {
                                    final page = _pageController.hasClients &&
                                            _pageController
                                                .position.hasContentDimensions
                                        ? (_pageController.page ??
                                            _focusedIndex.toDouble())
                                        : _focusedIndex.toDouble();
                                    final distanceInPages =
                                        (index - page).abs();
                                    final value = (1 - distanceInPages * 0.4)
                                        .clamp(0.0, 1.0);
                                    final scale =
                                        Curves.easeOut.transform(value);
                                    return Transform.scale(
                                        scale: scale, child: child);
                                  },
                                  child: GestureDetector(
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
                                    child: Container(
                                      margin: const EdgeInsets.all(10),
                                      child: Image.network(
                                        team.imagePath ?? '',
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(Icons.shield,
                                                color: Colors.white54,
                                                size: 80),
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
                                    focusedTeam?.name ?? '',
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
                          const Column(
                            children: [
                              Text("Select your favorite club(s)",
                                  style: Heading5.style),
                              SizedBox(height: 6),
                              Text("You may choose up to 1 team per league",
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
                                                  team.name,
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
                              onPressed: _selectedTeams.isEmpty
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RankFavoriteTeamsScreen(
                                            selectedTeams:
                                                _selectedTeams.values.toList(),
                                          ),
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colors.onSurface,
                                minimumSize: const Size(double.infinity, 56),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16)),
                                disabledBackgroundColor:
                                    appColors.subtleBackground,
                              ),
                              child: Text("CONTINUE",
                                  style: Body2_b.style
                                      .copyWith(color: colors.surface)),
                            ),
                          ),
                          SizedBox(height: bottomGap),
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
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Image.network(
                      league.imagePath ?? '',
                      width: 24,
                      height: 24,
                      errorBuilder: (_, __, ___) => competitionLogoFallback(
                          league.competitionId,
                          size: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedLeague,
                        style: Heading5.style.copyWith(color: onBrand),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isDropdownOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: onBrand,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
