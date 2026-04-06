import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/matchdata.dart';
import 'package:onetouch/features/MatchInfoFeatures.dart';
import 'package:onetouch/features/KaneRest.dart';

class MatchInfoTab extends StatelessWidget {
  final String matchId;
  final String matchStatus; // "past" | "live"

  MatchInfoTab({
    super.key,
    required this.matchId,
    required this.matchStatus,
  });

  bool get isLive => matchStatus == 'live';

  // ── Mock data — replace with real API models ──

  final List<Substitute> _subsA = [
    Substitute(name: "Ferran Torres", minute: 82, goal: true, subIn: true),
    Substitute(name: "Raphinha"),
    Substitute(name: "Eric García"),
  ];

  final List<Substitute> _subsB = [
    Substitute(name: "Tsygankov", minute: 82, subIn: true, goal: true),
    Substitute(name: "Dovbyk"),
    Substitute(name: "Blind"),
  ];

  final List<Map<String, dynamic>> _goalEvents = const [
    {'player': 'Lewandowski', 'minute': "23'", 'team': 'home'},
    {'player': 'Lewandowski', 'minute': "67'", 'team': 'home'},
    {'player': 'Dovbyk',      'minute': "45'", 'team': 'away'},
  ];

  final List<StatBarData> _statBars = const [
    StatBarData(category: "Possession",    homePercent: 64, awayPercent: 36),
    StatBarData(category: "Pass Accuracy", homePercent: 82, awayPercent: 78),
  ];

  // Away: rows ordered GK → attackers (shown top → bottom on pitch)
  final List<List<LineupPlayer>> _awayRows = const [
    [LineupPlayer(number: 13, name: 'Gazzaniga')],
    [
      LineupPlayer(number: 16, name: 'Francés'),
      LineupPlayer(number: 17, name: 'Blind'),
      LineupPlayer(number: 18, name: 'Krejci'),
      LineupPlayer(number: 3,  name: 'Gutiérrez',
          events: [LineupEvent(type: LineupEventType.yellowCard)]),
    ],
    [
      LineupPlayer(number: 8,  name: 'Tsigankov'),
      LineupPlayer(number: 4,  name: 'Martinez',
          events: [LineupEvent(type: LineupEventType.yellowCard)]),
      LineupPlayer(number: 12, name: 'Arthur'),
      LineupPlayer(number: 21, name: 'Herrera'),
    ],
    [
      LineupPlayer(number: 11, name: 'Danjuma'),
      LineupPlayer(number: 10, name: 'Asprilla',
          events: [LineupEvent(type: LineupEventType.redCard)]),
    ],
  ];

  // Home: rows ordered attackers → GK (shown top → bottom in home half)
  final List<List<LineupPlayer>> _homeRows = const [
    [
      LineupPlayer(number: 9, name: 'Lewandowski',
          events: [LineupEvent(type: LineupEventType.subIn, minute: 82)]),
    ],
    [
      LineupPlayer(number: 6,  name: 'Gavi',
          events: [LineupEvent(type: LineupEventType.subOut, minute: 82)]),
      LineupPlayer(number: 16, name: 'Lopez'),
      LineupPlayer(number: 11, name: 'Lamine Yamal',
          events: [LineupEvent(type: LineupEventType.goal)]),
    ],
    [
      LineupPlayer(number: 8,  name: 'Pedri',
          events: [LineupEvent(type: LineupEventType.goal)]),
      LineupPlayer(number: 24, name: 'Eric Garcia',
          events: [LineupEvent(type: LineupEventType.yellowCard)]),
    ],
    [
      LineupPlayer(number: 35, name: 'Martin'),
      LineupPlayer(number: 5,  name: 'Martinez',
          events: [LineupEvent(type: LineupEventType.yellowCard)]),
      LineupPlayer(number: 4,  name: 'Araujo'),
      LineupPlayer(number: 23, name: 'Koundé'),
    ],
    [LineupPlayer(number: 25, name: 'Szczesny')],
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MatchScoreHeader(
            homeLogoAsset: 'TeamLogos/Barcelona.png',
            awayLogoAsset: 'TeamLogos/Girona.png',
            homeTeamName: 'Team Name',
            awayTeamName: 'Team Name',
            homeScore: '#',
            awayScore: '#',
            statusLabel: isLive ? '42:02' : 'Final',
            venueName: 'Venue Name',
          ),
          const SizedBox(height: 12),
          MatchEventsSection(events: _goalEvents),
          if (!isLive) ...[
            const SizedBox(height: 24),
            const MatchHighlights(imageAsset: 'assets/highlight1.png'),
            const SizedBox(height: 32),
            const PlayerOfTheMatch(
              rating: '8.9',
              playerName: 'Player\nName',
              teamAndNumber: 'Team Name • ##',
            ),
          ],
          const SizedBox(height: 48),
          const MomentumChart(),
          const SizedBox(height: 48),
          StatBarsSection(bars: _statBars),
          const SizedBox(height: 48),
          LineupPitch(
            awayRows: _awayRows,
            homeRows: _homeRows,
            onPlayerTap: _onPlayerTap,
          ),
          const SizedBox(height: 48),
          SubstitutesAndCoach(
            subsA: _subsA,
            subsB: _subsB,
            coachA: 'Xavi',
            coachB: 'Michel',
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _onPlayerTap(BuildContext context, LineupPlayer player) {
    showPlayerMatchStatSheet(context, _buildStatData(player));
  }

  /// Map a LineupPlayer to PlayerMatchStatData.
  /// Replace stub sections with real data from your API model.
  PlayerMatchStatData _buildStatData(LineupPlayer player) {
    return PlayerMatchStatData(
      name: player.name,
      jerseyNumber: player.number,
      positions: ['—'],        // TODO: from API
      club: 'Club Name',       // TODO: from API
      nationality: 'Country',  // TODO: from API
      sections: const [
        PlayerMatchStatSection(
          category: 'FINISH',
          rows: [
            PlayerMatchStatRow(label: 'Goals', value: '0'),
            PlayerMatchStatRow(label: 'xG',    value: '0.0'),
          ],
        ),
      ],
    );
  }
}