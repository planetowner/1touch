import 'dart:ui'; // [NEW] Required for ImageFilter (Blur)
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'RankFavTeams.dart';


class SelectFavoriteTeamsScreen extends StatefulWidget {
  const SelectFavoriteTeamsScreen({super.key});

  @override
  State<SelectFavoriteTeamsScreen> createState() =>
      _SelectFavoriteTeamsScreenState();
}

class _SelectFavoriteTeamsScreenState extends State<SelectFavoriteTeamsScreen> {

  // --- DATA ---
  final Map<String, List<Map<String, String>>> leagues = {
    "Premier League": [
      {
        "name": "Manchester City",
        "shortName": "MAN CITY",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/e/eb/Manchester_City_FC_badge.svg/1200px-Manchester_City_FC_badge.svg.png"
      },
      {
        "name": "Liverpool FC",
        "shortName": "LIVERPOOL",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/0/0c/Liverpool_FC.svg/1200px-Liverpool_FC.svg.png"
      },
      {
        "name": "Arsenal FC",
        "shortName": "ARSENAL",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/5/53/Arsenal_FC.svg/1200px-Arsenal_FC.svg.png"
      },
    ],
    "La Liga": [
      {
        "name": "FC Barcelona",
        "shortName": "BARCELONA",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/4/47/FC_Barcelona_%28crest%29.svg/1200px-FC_Barcelona_%28crest%29.svg.png"
      },
      {
        "name": "Real Madrid CF",
        "shortName": "REAL MADRID",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/5/56/Real_Madrid_CF.svg/1200px-Real_Madrid_CF.svg.png"
      },
      {
        "name": "Atlético Madrid",
        "shortName": "ATLÉTICO",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/f/f4/Atletico_Madrid_2017_logo.svg/800px-Atletico_Madrid_2017_logo.svg.png"
      },
    ],
    "Bundesliga": [
      {
        "name": "FC Bayern Munich",
        "shortName": "BAYERN",
        "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1b/FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg/1200px-FC_Bayern_M%C3%BCnchen_logo_%282017%29.svg.png"
      },
      {
        "name": "Borussia Dortmund",
        "shortName": "DORTMUND",
        "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/6/67/Borussia_Dortmund_logo.svg/1200px-Borussia_Dortmund_logo.svg.png"
      },
    ],
    "Serie A": [
      {
        "name": "Inter Milan",
        "shortName": "INTER",
        "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/FC_Internazionale_Milano_2021.svg/1200px-FC_Internazionale_Milano_2021.svg.png"
      },
      {
        "name": "Juventus",
        "shortName": "JUVENTUS",
        "logo": "https://upload.wikimedia.org/wikipedia/commons/thumb/b/bc/Juventus_FC_2017_icon_%28black%29.svg/1200px-Juventus_FC_2017_icon_%28black%29.svg.png"
      },
    ],
    "Ligue 1": [
      {
        "name": "Paris Saint-Germain",
        "shortName": "PSG",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/a/a7/Paris_Saint-Germain_F.C..svg/1200px-Paris_Saint-Germain_F.C..svg.png"
      },
      {
        "name": "AS Monaco",
        "shortName": "MONACO",
        "logo": "https://upload.wikimedia.org/wikipedia/en/thumb/b/ba/AS_Monaco_FC.svg/1200px-AS_Monaco_FC.svg.png"
      },
    ],
  };

  final Map<String, List<Color>> teamGradients = {
    "FC Barcelona":        [const Color(0xFFD82457), const Color(0x00D82457)],
    "Real Madrid CF":      [const Color(0xFFF1F1F1), const Color(0xFFB59B00)],
    "Atlético Madrid":     [const Color(0xFFC2232A), const Color(0xFF15244C)],
    "Manchester City":     [const Color(0xFF6CABDD), const Color(0xFF1C2C5B)],
    "Liverpool FC":        [const Color(0xFFC8102E), const Color(0xFF00A398)],
    "Arsenal FC":          [const Color(0xFFEF0107), const Color(0xFF9C824A)],
    "FC Bayern Munich":    [const Color(0xFFD20000), const Color(0xFF0066B2)],
    "Borussia Dortmund":   [const Color(0xFFFFEE00), const Color(0xFF000000)],
    "Inter Milan":         [const Color(0xFF0033A0), const Color(0xFF000000)],
    "Juventus":            [const Color(0xFFFFFFFF), const Color(0xFF000000)],
    "Paris Saint-Germain": [const Color(0xFF004170), const Color(0xFFDA291C)],
    "AS Monaco":           [const Color(0xFFDA291C), const Color(0xFFFED100)],
  };

  final Map<String, String> leagueIcons = {
    "Premier League": "https://example.com/icons/premierleague.png",
    "La Liga": "https://example.com/icons/laliga.png",
    "Bundesliga": "https://example.com/icons/bundesliga.png",
    "Serie A": "https://example.com/icons/seriea.png",
    "Ligue 1": "https://example.com/icons/ligue1.png",
  };

  late PageController _pageController;
  int _focusedIndex = 0;
  String? _focusedTeamName;

  // [NEW] Variables for Custom Dropdown Overlay
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isDropdownOpen = false;

  Gradient _gradientForFocusedTeam() {
    final name = _focusedTeamName;
    final colors = (name != null) ? teamGradients[name] : null;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors ?? const [Color(0xFF1F1F1F), Color(0xFF000000)],
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.6);

    if (leagues[selectedLeague] != null && leagues[selectedLeague]!.isNotEmpty) {
      _focusedTeamName = leagues[selectedLeague]!.first["name"];
    }
  }

  @override
  void dispose() {
    // [NEW] Ensure overlay is removed when leaving screen
    _removeOverlay();
    _pageController.dispose();
    super.dispose();
  }

  String selectedLeague = "Premier League";
  final Map<String, String> selectedTeams = {};

  // --- [NEW] OVERLAY LOGIC ---

  void _toggleDropdown() {
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isDropdownOpen = false;
    });
  }

  void _showOverlay() {
    // 1. Create the overlay entry
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Barrier (Transparent): Closes dropdown if you click outside
          GestureDetector(
            onTap: _removeOverlay,
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),

          // The Dropdown Menu
          Positioned(
            width: 223, // Fixed width matching the button
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(0, 0), // Opens exactly on top of button
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        // [FIX] Brown/Gold tint from Figma Design
                        color: const Color(0xFF5C4C3A).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: leagues.keys.map((league) {
                          final isSelected = league == selectedLeague;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                selectedLeague = league;
                                _focusedIndex = 0;
                                _focusedTeamName = leagues[selectedLeague]!.first["name"];
                              });
                              _pageController.jumpToPage(0);
                              _removeOverlay();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Image.network(
                                    leagueIcons[league] ?? '',
                                    height: 20, width: 20,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.shield, size: 20, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      league,
                                      style: isSelected
                                          ? Heading5.style.copyWith(fontWeight: FontWeight.bold)
                                          : Heading5.style.copyWith(color: Colors.white70),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20)
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

    // 2. Insert into Overlay
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isDropdownOpen = true;
    });
  }
  // ---------------------------

  @override
  Widget build(BuildContext context) {
    final teams = leagues[selectedLeague]!;
    final currentTeamData = teams[_focusedIndex];
    final isFocusedTeamSelected = selectedTeams[selectedLeague] == currentTeamData["shortName"];

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
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.transparent, Color(0xFF0C0C0C), Color(0xFF000000)],
                    stops:  [0.0, 0.40, 0.85, 1.0],
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SvgPicture.asset(
                          'assets/app_logo.svg',
                          height: 23,
                          width: 120,
                          placeholderBuilder: (_) => const Text("1TOUCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                        ),
                        Switch(
                          value: false,
                          onChanged: (_) {},
                          activeColor: Colors.white,
                          inactiveTrackColor: Colors.white24,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // [FIX] Custom Dropdown Button
                  _buildLeagueDropdown(),

                  const Spacer(flex: 1),

                  // Carousel
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: teams.length,
                      onPageChanged: (i) {
                        setState(() {
                          _focusedIndex = i;
                          _focusedTeamName = teams[i]["name"];
                        });
                      },
                      itemBuilder: (context, index) {
                        return AnimatedBuilder(
                          animation: _pageController,
                          builder: (context, child) {
                            double value = 1.0;
                            if (_pageController.position.haveDimensions) {
                              value = _pageController.page! - index;
                              value = (1 - (value.abs() * 0.4)).clamp(0.0, 1.0);
                            } else {
                              value = index == _focusedIndex ? 1.0 : 0.6;
                            }
                            final curve = Curves.easeOut.transform(value);

                            return Transform.scale(
                              scale: curve,
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            // Inside onTap in the PageView builder:
                            onTap: () {
                              // Use "shortName" here instead of "name"
                              final tappedTeamShort = teams[index]["shortName"]!;

                              setState(() {
                                // Check if this short name is already in the map values
                                if (selectedTeams.containsValue(tappedTeamShort)) {
                                  selectedTeams.remove(selectedLeague);
                                } else {
                                  selectedTeams[selectedLeague] = tappedTeamShort;
                                }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              child: Image.network(
                                teams[index]["logo"]!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                const Icon(Icons.shield, color: Colors.white54, size: 80),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Name + Checkmark
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _focusedTeamName ?? "",
                        style: Heading4.style,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 8),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isFocusedTeamSelected ? 1.0 : 0.0,
                        child: const Icon(Icons.check_circle, color: Colors.blueAccent, size: 24),
                      ),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Instruction text
                  Column(
                    children: const [
                      Text("Select your favorite club(s)", style: Heading5.style),
                      SizedBox(height: 6),
                      Text("You may choose up to 1 team per league", style: Body2.style),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Place this code above the "CONTINUE" button in your column

                  Container(
                    // Limit height so it doesn't push the button off-screen if many teams are selected
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    constraints: const BoxConstraints(minHeight: 50, maxHeight: 150),
                    child: selectedTeams.isNotEmpty
                        ? SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,      // Horizontal gap between pills
                        runSpacing: 10,  // Vertical gap between lines
                        children: selectedTeams.values.map((t) {
                          return Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF333333), // Dark grey background
                              borderRadius: BorderRadius.circular(16), // Pill shape
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min, // Shrink to fit text
                              children: [
                                Text(
                                  t.toUpperCase(), // All caps
                                  style: Body2_b.style.copyWith(color: Colors.white70),
                                ),
                                const SizedBox(width: 8),

                                // Custom Close Button
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedTeams.removeWhere((_, v) => v == t);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 24,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    )
                        : const SizedBox(height: 50), // Placeholder to keep layout stable when empty
                  ),

                  const SizedBox(height: 20),

                  // Continue button
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ElevatedButton(
                        onPressed: selectedTeams.isEmpty
                            ? null
                            : () {
                          // Convert the map values (team names) to a list
                          List<String> chosenTeams = selectedTeams.values.toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RankFavoriteTeamsScreen(
                                selectedTeams: chosenTeams,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: Colors.white10,
                        ),
                        child: Text(
                          "CONTINUE",
                          style: Body2_b.style.copyWith(color: Colors.black),
                        ),
                      )
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          )
        ]
    );
  }

  // [FIX] New "Button" that anchors the Overlay
  Widget _buildLeagueDropdown() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _toggleDropdown,
        child: Container(
          width: 223,
          padding: const EdgeInsets.fromLTRB(16,12,8,12),
          decoration: BoxDecoration(
            // Default state: slightly glassy white
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.network(
                    leagueIcons[selectedLeague] ?? '',
                    height: 24, width: 24,
                    errorBuilder: (_, __, ___) => const Icon(Icons.sports_soccer, size: 24, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(selectedLeague, style: Heading5.style),
                ],
              ),
              const SizedBox(width: 8),
              // Arrow changes based on open/closed state
              Icon(
                  _isDropdownOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white
              ),
            ],
          ),
        ),
      ),
    );
  }
}