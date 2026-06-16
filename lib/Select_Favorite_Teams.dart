import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/models/league.dart';
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
  late List<League> _leagues;
  late Map<int, List<Team>> _leagueTeams; // leagueId → teams sorted by standing

  late String selectedLeague;
  int get _selectedLeagueId =>
      _leagues.firstWhere((l) => l.name == selectedLeague).leagueId;

  final Map<int, Team> _selectedTeams = {};

  late ScrollController _scrollController;
  double _itemWidth = 0; // set in build from MediaQuery
  int _focusedIndex = 0;
  Team? _focusedTeam;

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();

    _leagues = mockLeagues
        .where((l) => _domesticLeagueIds.contains(l.leagueId))
        .toList();

    _leagueTeams = {};
    for (final league in _leagues) {
      final standingsForLeague = mockStandings
          .where((s) => s.leagueId == league.leagueId)
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      _leagueTeams[league.leagueId] = standingsForLeague
          .map((s) => mockTeamById(s.teamId))
          .toList();
    }

    selectedLeague = _leagues.first.name;
    _focusedTeam = _leagueTeams[_selectedLeagueId]?.first;

    _scrollController = ScrollController()..addListener(_onScroll);
  }

  void _onScroll() {
    if (_itemWidth == 0) return;
    final newIndex = (_scrollController.offset / _itemWidth)
        .round()
        .clamp(0, _currentTeams.length - 1);
    if (newIndex != _focusedIndex) {
      setState(() {
        _focusedIndex = newIndex;
        _focusedTeam = _currentTeams[newIndex];
      });
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _scrollController.dispose();
    super.dispose();
  }

  List<Team> get _currentTeams => _leagueTeams[_selectedLeagueId] ?? [];

  Gradient _gradientForFocusedTeam() {
    final color = _focusedTeam != null
        ? Color(_focusedTeam!.primaryColor)
        : const Color(0xFF1F1F1F);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color, Colors.black],
    );
  }

  // --- OVERLAY LOGIC ---

  void _toggleDropdown() =>
      _isDropdownOpen ? _removeOverlay() : _showOverlay();

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isDropdownOpen = false);
  }

  void _showOverlay() {
    final dropdownWidth = MediaQuery.of(context).size.width * 0.6;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
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
                        color: const Color(0xFF5C4C3A).withValues(alpha: 0.6),
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
                                    _leagueTeams[league.leagueId]?.first;
                              });
                              _scrollController.jumpTo(0);
                              _removeOverlay();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Image.network(
                                    league.imagePath ?? '',
                                    height: 20,
                                    width: 20,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.shield,
                                        size: 20,
                                        color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      league.name,
                                      style: isSelected
                                          ? Heading5.style.copyWith(
                                              fontWeight: FontWeight.bold)
                                          : Heading5.style
                                              .copyWith(color: Colors.white70),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.keyboard_arrow_up,
                                        color: Colors.white, size: 20),
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
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isDropdownOpen = true);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    _itemWidth = screenWidth * 0.6;
    final sidePadding = (screenWidth - _itemWidth) / 2;

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
          decoration: BoxDecoration(gradient: _gradientForFocusedTeam()),
        ),

        // 2) Vignette
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xFF0C0C0C),
                    Color(0xFF000000),
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
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SvgPicture.asset(
                        'assets/app_logo.svg',
                        height: 23,
                        width: 120,
                        placeholderBuilder: (_) => const Text("1TOUCH",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20)),
                      ),
                      Switch(
                        value: false,
                        onChanged: (_) {},
                        activeThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white24,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Dropdown
                _buildLeagueDropdown(),

                const Spacer(flex: 1),

                // Smooth-scrolling carousel
                SizedBox(
                  height: 220,
                  child: ListView.builder(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding:
                        EdgeInsets.symmetric(horizontal: sidePadding),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      return AnimatedBuilder(
                        animation: _scrollController,
                        builder: (context, child) {
                          double scale;
                          if (_scrollController.hasClients) {
                            final offset = _scrollController.offset;
                            final distanceInPages =
                                ((index * _itemWidth) - offset).abs() /
                                    _itemWidth;
                            final value =
                                (1 - distanceInPages * 0.4).clamp(0.0, 1.0);
                            scale = Curves.easeOut.transform(value);
                          } else {
                            scale = index == _focusedIndex ? 1.0 : 0.6;
                          }
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (_selectedTeams[_selectedLeagueId]?.teamId ==
                                  team.teamId) {
                                _selectedTeams.remove(_selectedLeagueId);
                              } else {
                                _selectedTeams[_selectedLeagueId] = team;
                              }
                            });
                          },
                          child: SizedBox(
                            width: _itemWidth,
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              child: Image.network(
                                team.imagePath ?? '',
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const Icon(
                                    Icons.shield,
                                    color: Colors.white54,
                                    size: 80),
                              ),
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
                                      color: Colors.blueAccent, size: 24),
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
                    Text("Select your favorite club(s)", style: Heading5.style),
                    SizedBox(height: 6),
                    Text("You may choose up to 1 team per league",
                        style: Body2.style),
                  ],
                ),

                const SizedBox(height: 16),

                // Selected team chips
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  constraints:
                      const BoxConstraints(minHeight: 50, maxHeight: 150),
                  child: _selectedTeams.isNotEmpty
                      ? SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 10,
                            children: _selectedTeams.values.map((team) {
                              return Container(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 8, 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF333333),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      team.shortCode ?? team.name,
                                      style: Body2_b.style
                                          .copyWith(color: Colors.white70),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedTeams.removeWhere(
                                              (_, v) =>
                                                  v.teamId == team.teamId);
                                        });
                                      },
                                      child: const Icon(Icons.close,
                                          size: 24, color: Colors.white70),
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
                                builder: (_) => RankFavoriteTeamsScreen(
                                  selectedTeams:
                                      _selectedTeams.values.toList(),
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      disabledBackgroundColor: Colors.white10,
                    ),
                    child: Text("CONTINUE",
                        style: Body2_b.style.copyWith(color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeagueDropdown() {
    final league = _leagues.firstWhere((l) => l.name == selectedLeague);
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.network(
                    league.imagePath ?? '',
                    height: 24,
                    width: 24,
                    errorBuilder: (_, __, ___) => const Icon(
                        Icons.sports_soccer,
                        size: 24,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(selectedLeague, style: Heading5.style),
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                _isDropdownOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}