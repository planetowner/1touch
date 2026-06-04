import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:onetouch/features/StandingFeatures.dart';

class StandingTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const StandingTab({super.key, required this.team});

  @override
  State<StandingTab> createState() => _StandingTabState();
}

class _StandingTabState extends State<StandingTab> {
  // xG standings are only available for Big 5 leagues
  static const _big5LeagueIds = {8, 82, 301, 384, 564};

  int selectedLeagueId = 8;
  int selectedSeasonId = 23614;
  bool isScrolledToEnd = false;

  final ScrollController _horizontalScrollController = ScrollController();

  // Two separate data sources — different shapes, different endpoints.
  List<Map<String, dynamic>> standings = [];
  List<Map<String, dynamic>> xgStandings = [];

  int? currentTeamId;
  List<int> _validLeagueIds = [];

  StandingView _selectedView = StandingView.standing;
  bool _isViewDropdownOpen = false;

  bool get _xgAvailable => _big5LeagueIds.contains(selectedLeagueId);

  @override
  void initState() {
    super.initState();

    currentTeamId = widget.team?['id'] as int?;
    final fixtures = currentTeamId != null
        ? fixturesByTeam(currentTeamId!)
        : const <Fixture>[];

    _validLeagueIds = fixtures
        .map((f) => f.leagueId)
        .toSet()
        .where((id) => standingsByLeague(id).isNotEmpty)
        .toList();

    final leagueId = _validLeagueIds.isNotEmpty
        ? _validLeagueIds.first
        : mockLeagues.first.leagueId;

    final seasonId = mockSeasons
        .firstWhere(
          (s) => s.leagueId == leagueId && s.isCurrent,
      orElse: () => mockSeasons.first,
    )
        .seasonId;

    selectedLeagueId = leagueId;
    selectedSeasonId = seasonId;

    _loadData();

    _horizontalScrollController.addListener(_handleHorizontalScroll);
  }

  @override
  void dispose() {
    _horizontalScrollController.removeListener(_handleHorizontalScroll);
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _handleHorizontalScroll() {
    final controller = _horizontalScrollController;
    if (!controller.hasClients) return;

    final atEnd = controller.offset >= controller.position.maxScrollExtent - 4;
    if (isScrolledToEnd != atEnd) {
      setState(() => isScrolledToEnd = atEnd);
    }
  }

  void _loadData() {
    // ── Standings (always) ───────────────────────────────────────────
    final standingRows = standingsByLeague(selectedLeagueId);
    final newStandings = standingRows.map((s) {
      final team = mockTeamById(s.teamId);
      return {
        'rank': s.position,
        'teamId': s.teamId,
        'team': team.shortCode ?? team.name,
        'logo': team.imagePath ?? '',
        'mp': s.matchesPlayed,
        'w': s.won,
        'd': s.draw,
        'l': s.lost,
        'gf': s.goalsFor,
        'ga': s.goalsAgainst,
        'pts': s.points,
        'last5': s.last5Form,
      };
    }).toList();

    // ── xG standings (Big 5 only — different source/endpoint) ───────
    List<Map<String, dynamic>> newXg = [];
    if (_xgAvailable) {
      final xgRows = xgStandingsByLeague(selectedLeagueId);
      newXg = xgRows.map((x) {
        final team = mockTeamById(x.teamId);
        return {
          'rank': x.position,
          'teamId': x.teamId,
          'team': team.shortCode ?? team.name,
          'logo': team.imagePath ?? '',
          'mp': x.matchesPlayed,
          'w': x.won,
          'd': x.draw,
          'l': x.lost,
          'xg': x.xg,
          'xga': x.xga,
          'xpts': x.xpts,
        };
      }).toList();
    }

    setState(() {
      standings = newStandings;
      xgStandings = newXg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate(
            [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 24),
                child: Row(
                  children: [
                    _buildLeagueDropdown(),
                    const SizedBox(width: 16),
                    _buildSeasonDropdown(),
                  ],
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 16),
                        child: StandingViewSelector(
                          selectedView: _selectedView,
                          isOpen: _isViewDropdownOpen,
                          onToggle: () {
                            setState(() {
                              _isViewDropdownOpen = !_isViewDropdownOpen;
                            });
                          },
                        ),
                      ),
                      _buildSelectedTable(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          StandingsLegend(leagueId: selectedLeagueId),
                        ],
                      )
                    ],
                  ),
                  if (_isViewDropdownOpen)
                    Positioned(
                      top: 42,
                      left: 24,
                      child: StandingViewOptions(
                        selectedView: _selectedView,
                        availableViews: _availableViews,
                        onChanged: _changeStandingView,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 144),
            ],
          ),
        ),
      ],
    );
  }

  void _changeStandingView(StandingView view) {
    setState(() {
      _selectedView = view;
      _isViewDropdownOpen = false;
    });
  }

  // Which views are usable for the currently selected league.
  // xG TABLE is hidden entirely for non-Big-5 leagues.
  List<StandingView> get _availableViews => [
    StandingView.standing,
    if (_xgAvailable) StandingView.xgTable,
  ];

  Widget _buildSelectedTable() {
    switch (_selectedView) {
      case StandingView.standing:
        return StandingTable(
          standings: standings,
          currentTeamId: currentTeamId,
          leagueId: selectedLeagueId,
          horizontalScrollController: _horizontalScrollController,
          isScrolledToEnd: isScrolledToEnd,
        );
      case StandingView.xgTable:
        return XgTable(
          standings: xgStandings,
          currentTeamId: currentTeamId,
          leagueId: selectedLeagueId,
          horizontalScrollController: _horizontalScrollController,
          isScrolledToEnd: isScrolledToEnd,
        );
    }
  }

  Widget _buildLeagueDropdown() {
    final availableLeagues = _validLeagueIds.isNotEmpty
        ? mockLeagues.where((l) => _validLeagueIds.contains(l.leagueId)).toList()
        : mockLeagues;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: const Color(0xFF3D3D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedLeagueId,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF3D3D3D),
          style: Body2_b.style,
          onChanged: (val) {
            if (val == null) return;
            final season = mockSeasons.firstWhere(
                  (s) => s.leagueId == val && s.isCurrent,
              orElse: () => mockSeasons.firstWhere((s) => s.leagueId == val),
            );
            setState(() {
              selectedLeagueId = val;
              selectedSeasonId = season.seasonId;
              _isViewDropdownOpen = false;
              // If user was viewing xG and new league isn't Big 5, fall back
              if (!_xgAvailable && _selectedView == StandingView.xgTable) {
                _selectedView = StandingView.standing;
              }
            });
            _loadData();
          },
          items: availableLeagues
              .map(
                (l) => DropdownMenuItem(
              value: l.leagueId,
              child: Text(l.name, style: Body2_b.style),
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSeasonDropdown() {
    final seasons = mockSeasons
        .where((s) => s.leagueId == selectedLeagueId)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: ShapeDecoration(
        color: const Color(0xFF3D3D3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedSeasonId,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          dropdownColor: const Color(0xFF3D3D3D),
          style: Body2_b.style,
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              selectedSeasonId = val;
              _isViewDropdownOpen = false;
            });
            _loadData();
          },
          items: seasons
              .map(
                (s) => DropdownMenuItem(
              value: s.seasonId,
              child: Text(s.name, style: Body2_b.style),
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}