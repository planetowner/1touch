import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class Match {
  final int? matchid;
  final String homeTeam;
  final String awayTeam;
  final DateTime startTime;
  final DateTime endTime;
  final int? homeScore;
  final int? awayScore;
  final String league;
  final String round;

  Match({
    required this.homeTeam,
    required this.awayTeam,
    required this.startTime,
    required this.endTime,
    this.homeScore,
    this.awayScore,
    required this.league,
    required this.round,
    this.matchid,
  });
}

class MatchesTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const MatchesTab({super.key, required this.team});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _liveSectionKey = GlobalKey();

  List<Match> pastMatches = [];
  List<Match> liveMatches = [];
  List<Match> upcomingMatches = [];

  @override
  void initState() {
    super.initState();
    final List<Match> allMatches = getDummyMatches();
    categorizeMatches(allMatches);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToLiveSection();
    });
  }

  void scrollToLiveSection() {
    final RenderBox? renderBox =
    _liveSectionKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox != null) {
      final offset = renderBox.localToGlobal(Offset.zero).dy;
      final screenHeight = MediaQuery.of(context).size.height;
      final liveHeight = renderBox.size.height;

      // Center the live section in the screen
      final scrollOffset = _scrollController.offset + offset - (screenHeight / 2) + (liveHeight / 2);

      _scrollController.jumpTo(scrollOffset);
    }
  }

  void categorizeMatches(List<Match> allMatches) {
    final now = DateTime.now();
    pastMatches.clear();
    liveMatches.clear();
    upcomingMatches.clear();

    for (var match in allMatches) {
      if (match.endTime.isBefore(now)) {
        pastMatches.add(match);
      } else if (match.startTime.isBefore(now) && match.endTime.isAfter(now)) {
        liveMatches.add(match);
      } else {
        upcomingMatches.add(match);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            if (pastMatches.isNotEmpty) buildSection("PAST", pastMatches),
            buildSection("• LIVE", liveMatches),
            if (upcomingMatches.isNotEmpty) buildSection("UPCOMING", upcomingMatches),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 30,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildSection(String title, List<Match> matches, {Key? key}) {
    final showDivider = title != "PAST"; // Only show for LIVE and UPCOMING
    final isLive = title == "• LIVE";

    return Container(
      key: isLive ? _liveSectionKey : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDivider)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Divider(
                color: Color(0xFF3D3D3D),
                thickness: 0.7,
              ),
            ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              title,
              style: Body2_b.style,
            ),
          ),
          const SizedBox(height: 8),
          ...matches.map(buildMatchCard),
        ],
      ),
    );
  }

  Widget buildMatchCard(Match match) {
    final isUpcoming = match.startTime.isAfter(DateTime.now());
    // final isLive = match.startTime.isBefore(DateTime.now()) && match.endTime.isAfter(DateTime.now());

    final matchId = match.matchid.toString();

    // final isDimmed;

    return GestureDetector(
      onTap: () {
        final now = DateTime.now();
        String matchStatus;

        if (match.endTime.isBefore(now)) {
          matchStatus = 'past';
        } else if (match.startTime.isBefore(now) && match.endTime.isAfter(now)) {
          matchStatus = 'live';
        } else {
          matchStatus = 'upcoming';
        }

        GoRouter.of(context).push('/match/$matchId?status=$matchStatus');
      },
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield, color: Colors.black), // Placeholder
                  const SizedBox(width: 10),
                  Text(match.homeTeam, style: Heading5.style),
                  const Spacer(),
                  isUpcoming
                      ? Text(
                    DateFormat('E, MMM d\nh:mm a').format(match.startTime),
                    style: Body2.style,
                    textAlign: TextAlign.center,
                  )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Scoreboard(
                        match.homeScore?? 0,
                        isDimmed: match.homeScore! < match.awayScore!
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        ":",
                        style: Heading5.style,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(width: 4),
                      Scoreboard(
                          match.awayScore ?? 0,
                          isDimmed: match.awayScore! < match.homeScore!
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(match.awayTeam, style: Heading5.style),
                  const SizedBox(width: 10),
                  const Icon(Icons.shield, color: Colors.black),
                ],
              ),
              isUpcoming
                  ? Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 24, height: 1, color: Colors.white.withOpacity(0.3)),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ]
              )
                  : const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    match.league,
                    style: Body2.style,
                    textAlign: TextAlign.center,
                  ),
                  const Text(
                    " • ",
                    style: Body2.style,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    match.round,
                    style: Body2.style,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          )
      ),
    );
  }

  Widget Scoreboard(int score, {required bool isDimmed}){
    return Opacity(
      opacity: isDimmed ? 0.5 : 1.0,
      child: Material(
        // elevation: 5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          alignment: Alignment.center, // Centers the text
          decoration: BoxDecoration(
            color: Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            score.toString(),
            textAlign: TextAlign.center,
            style: Heading3.style,
          ),
        ),
      ),
    );
  }

  /// Dummy data — Replace this with your real API/data
  List<Match> getDummyMatches() {
    final now = DateTime.now();
    return [
      Match(
        matchid: 10,
        homeTeam: 'ABC',
        awayTeam: 'DEF',
        startTime: now.subtract(const Duration(hours: 10)),
        endTime: now.subtract(const Duration(hours: 5)),
        homeScore: 3,
        awayScore: 3,
        league: 'La Liga',
        round: 'Matchday 24',
      ),
      Match(
        matchid: 20,
        homeTeam: 'ABC',
        awayTeam: 'DEF',
        startTime: now.subtract(const Duration(hours: 5)),
        endTime: now.subtract(const Duration(hours: 2)),
        homeScore: 4,
        awayScore: 0,
        league: 'La Liga',
        round: 'Matchday 25',
      ),
      Match(
        matchid: 30,
        homeTeam: 'ABC',
        awayTeam: 'DEF',
        startTime: now.subtract(const Duration(hours: 3)),
        endTime: now.subtract(const Duration(hours: 1)),
        homeScore: 1,
        awayScore: 2,
        league: 'La Liga',
        round: 'Matchday 26',
      ),
      Match(
        matchid: 40,
        homeTeam: 'ABC',
        awayTeam: 'DEF',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now.add(const Duration(minutes: 60)),
        homeScore: 0,
        awayScore: 0,
        league: 'Copa del Rey',
        round: 'Semi-Final',
      ),
      Match(
        matchid: 50,
        homeTeam: 'ABC',
        awayTeam: 'DEF',
        startTime: now.add(const Duration(days: 1)),
        endTime: now.add(const Duration(days: 1, hours: 2)),
        league: 'UCL',
        round: 'Round of 16',
      ),
    ];
  }
}