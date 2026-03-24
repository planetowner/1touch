import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:go_router/go_router.dart';

class ComparisonPlayer {
  final String id;
  final String fullName;
  final String shortName;
  final String team;
  final int number;
  final Color teamColor;
  final Map<String, List<String>> clubSeasons;
  final List<double> radarValues; // 6 values, 0.0–1.0
  final List<CompStatCategory> statCategories;

  const ComparisonPlayer({
    required this.id,
    required this.fullName,
    required this.shortName,
    required this.team,
    required this.number,
    required this.teamColor,
    required this.clubSeasons,
    required this.radarValues,
    required this.statCategories,
  });
}

class CompStatCategory {
  final String label;
  final List<CompStatRow> rows;

  const CompStatCategory({required this.label, required this.rows});
}

class CompStatRow {
  final String name;
  final double value;
  final String display;

  const CompStatRow(
      {required this.name, required this.value, required this.display});
}

// STATIC DATA  (matches the screenshots)

const List<String> _kRadarLabels = [
  'Pace',
  'Shooting',
  'Passing',
  'Dribbling',
  'Defending',
  'Physical'
];

final List<ComparisonPlayer> kComparisonPlayers = [
  ComparisonPlayer(
    id: 'mctominay',
    fullName: 'Scott McTominay',
    shortName: 'SCOTT MCT...',
    team: 'Tottenham',
    number: 7,
    teamColor: const Color(0xFF132257),
    clubSeasons: {
      'Tottenham': ['24/25'],
      'Napoli': ['23/24'],
      'Man United': ['17/18', '18/19', '19/20', '20/21', '21/22', '22/23'],
    },
    radarValues: [0.72, 0.78, 0.68, 0.65, 0.80, 0.85],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 10, display: '10'),
        CompStatRow(name: 'xG', value: 0.56, display: '0.56'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 24, display: '24'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'grealish',
    fullName: 'Jack Grealish',
    shortName: 'JACK GREA...',
    team: 'Man City',
    number: 10,
    teamColor: const Color(0xFF6CABDD),
    clubSeasons: {
      'Manchester City': ['21/22', '22/23', '23/24', '24/25'],
      'Aston Villa': ['14/15', '15/16', '16/17', '17/18', '18/19', '20/21'],
      'Notts County': ['13/14'],
      'Aston Villa (U21)': ['12/13'],
    },
    radarValues: [0.82, 0.52, 0.88, 0.93, 0.32, 0.60],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 1, display: '1'),
        CompStatRow(name: 'xG', value: 0.24, display: '0.24'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 12, display: '12'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'mbappe',
    fullName: 'Kylian Mbappé',
    shortName: 'K. MBAPPÉ',
    team: 'Real Madrid',
    number: 9,
    teamColor: const Color(0xFF00529F),
    clubSeasons: {
      'Real Madrid': ['24/25'],
      'PSG': ['17/18', '18/19', '19/20', '20/21', '21/22', '22/23', '23/24'],
      'Monaco': ['15/16', '16/17'],
    },
    radarValues: [0.97, 0.90, 0.82, 0.95, 0.55, 0.80],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 27, display: '27'),
        CompStatRow(name: 'xG', value: 0.78, display: '0.78'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 45, display: '45'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'haaland',
    fullName: 'Erling Haaland',
    shortName: 'E. HAALAND',
    team: 'Man City',
    number: 9,
    teamColor: const Color(0xFF6CABDD),
    clubSeasons: {
      'Man City': ['22/23', '23/24', '24/25'],
      'Dortmund': ['20/21', '21/22'],
      'RB Salzburg': ['19/20'],
      'Molde': ['18/19'],
    },
    radarValues: [0.85, 0.98, 0.60, 0.75, 0.48, 0.92],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 36, display: '36'),
        CompStatRow(name: 'xG', value: 1.20, display: '1.20'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 18, display: '18'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'palmer',
    fullName: 'Cole Palmer',
    shortName: 'C. PALMER',
    team: 'Chelsea FC',
    number: 10,
    teamColor: const Color(0xFF034694),
    clubSeasons: {
      'Chelsea FC': ['23/24', '24/25'],
      'Man City': ['21/22', '22/23'],
      'Preston (loan)': ['20/21'],
    },
    radarValues: [0.75, 0.84, 0.90, 0.88, 0.45, 0.65],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 22, display: '22'),
        CompStatRow(name: 'xG', value: 0.65, display: '0.65'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 56, display: '56'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'saka',
    fullName: 'Bukayo Saka',
    shortName: 'B. SAKA',
    team: 'Arsenal',
    number: 11,
    teamColor: const Color(0xFFDB0007),
    clubSeasons: {
      'Arsenal': ['19/20', '20/21', '21/22', '22/23', '23/24', '24/25'],
    },
    radarValues: [0.88, 0.75, 0.86, 0.90, 0.60, 0.70],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 16, display: '16'),
        CompStatRow(name: 'xG', value: 0.55, display: '0.55'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 62, display: '62'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'salah',
    fullName: 'Mohamed Salah',
    shortName: 'M. SALAH',
    team: 'Liverpool',
    number: 11,
    teamColor: const Color(0xFFC8102E),
    clubSeasons: {
      'Liverpool': [
        '17/18',
        '18/19',
        '19/20',
        '20/21',
        '21/22',
        '22/23',
        '23/24',
        '24/25'
      ],
      'Roma': ['15/16', '16/17'],
      'Fiorentina (loan)': ['14/15'],
      'Chelsea': ['13/14'],
    },
    radarValues: [0.90, 0.87, 0.80, 0.92, 0.45, 0.72],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 28, display: '28'),
        CompStatRow(name: 'xG', value: 0.72, display: '0.72'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 48, display: '48'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'jackson',
    fullName: 'Nicolas Jackson',
    shortName: 'N. JACKSON',
    team: 'Chelsea',
    number: 15,
    teamColor: const Color(0xFF034694),
    clubSeasons: {
      'Chelsea': ['23/24', '24/25'],
      'Villarreal': ['22/23'],
      'Mallorca (loan)': ['21/22'],
    },
    radarValues: [0.82, 0.72, 0.62, 0.76, 0.40, 0.80],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 14, display: '14'),
        CompStatRow(name: 'xG', value: 0.45, display: '0.45'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 22, display: '22'),
      ]),
    ],
  ),
  ComparisonPlayer(
    id: 'hinshelwood',
    fullName: 'Jack Hinshelwood',
    shortName: 'J. HINSHELWOOD',
    team: 'Brighton',
    number: 41,
    teamColor: const Color(0xFF0057B8),
    clubSeasons: {
      'Brighton': ['22/23', '23/24', '24/25'],
    },
    radarValues: [0.70, 0.55, 0.74, 0.68, 0.65, 0.60],
    statCategories: [
      CompStatCategory(label: 'FINISH', rows: [
        CompStatRow(name: 'Goals', value: 4, display: '4'),
        CompStatRow(name: 'xG', value: 0.18, display: '0.18'),
      ]),
      CompStatCategory(label: 'PLAY MAKING', rows: [
        CompStatRow(name: 'Key Passes', value: 28, display: '28'),
      ]),
    ],
  ),
];

// Most compared pairs shown on the landing state (IDs)
const List<List<String>> _kMostCompared = [
  ['mbappe', 'haaland'],
  ['palmer', 'saka'],
  ['mctominay', 'salah'],
  ['mctominay', 'saka'],
];

ComparisonPlayer? _findById(String id) {
  for (final p in kComparisonPlayers) {
    if (p.id == id) return p;
  }
  return null;
}

ComparisonPlayer? findComparisonPlayerByName(String name) {
  final lower = name.toLowerCase();
  for (final p in kComparisonPlayers) {
    if (p.fullName.toLowerCase() == lower) return p;
  }
  return null;
}

// PLAYER COMPARISON SCREEN

class PlayerComparisonScreen extends StatefulWidget {
  /// Pass the current player's fullName to pre-fill slot 1
  final String? initialPlayerName;

  const PlayerComparisonScreen({super.key, this.initialPlayerName});

  @override
  State<PlayerComparisonScreen> createState() => _PlayerComparisonScreenState();
}

class _PlayerComparisonScreenState extends State<PlayerComparisonScreen> {
  ComparisonPlayer? _p1;
  ComparisonPlayer? _p2;
  String? _s1;
  String? _s2;

  late ScrollController _scrollController;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()
      ..addListener(() {
        setState(() {
          _scrollOffset = _scrollController.offset.clamp(0.0, 150.0);
        });
      });

    if (widget.initialPlayerName != null) {
      _p1 = findComparisonPlayerByName(widget.initialPlayerName!);
      if (_p1 != null && _p1!.clubSeasons.isNotEmpty) {
        _s1 = _p1!.clubSeasons.values.first.last;
      }
    }
  }

  bool get _bothReady => _p1 != null && _p2 != null;

  void _openPlayerPicker(int slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlayerPickerSheet(
        slot: slot,
        excludedId: slot == 1 ? _p2?.id : _p1?.id,
        onPick: (player) {
          Navigator.pop(context);
          _openSeasonPicker(slot, player);
        },
      ),
    );
  }

  void _openSeasonPicker(int slot, ComparisonPlayer player) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SeasonPickerSheet(
        player: player,
        onPick: (season) {
          Navigator.pop(context);
          setState(() {
            if (slot == 1) {
              _p1 = player;
              _s1 = season;
            } else {
              _p2 = player;
              _s2 = season;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double opacityFactor = (_scrollOffset / 150.0).clamp(0.0, 1.0);
    double gradientOpacity = 1.0 - opacityFactor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 400,
            child: AnimatedOpacity(
              opacity: gradientOpacity,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(282929), Color(000000)],
                    stops: [0.0, 0.6],
                  ),
                ),
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // App bar
              SliverAppBar(
                automaticallyImplyLeading: false,
                backgroundColor:
                    Color.lerp(Colors.transparent, Colors.black, opacityFactor),
                elevation: 0,
                floating: true,
                snap: true,
                toolbarHeight: 80,
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFD82457), Color(0x00D82457)],
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                title: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 30),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.chevron_left,
                        color: Colors.white, size: 32),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 30),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.push('/search'),
                          icon: const Icon(Icons.search, size: 32),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Comparison content as a sliver
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeaderArea(
                      p1: _p1,
                      p2: _p2,
                      s1: _s1,
                      s2: _s2,
                      onTap1: () => _openPlayerPicker(1),
                      onTap2: () => _openPlayerPicker(2),
                    ),
                    if (_bothReady)
                      _ComparisonContent(p1: _p1!, p2: _p2!)
                    else
                      _MostComparedSection(
                        onTapPair: (p1, p2) => setState(() {
                          _p1 = p1;
                          _s1 = p1.clubSeasons.values.first.last;
                          _p2 = p2;
                          _s2 = p2.clubSeasons.values.first.last;
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// TOP BAR
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 24),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search, size: 32, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// HEADER AREA  (chips + player photos with team-colour wash)

class _HeaderArea extends StatelessWidget {
  final ComparisonPlayer? p1, p2;
  final String? s1, s2;
  final VoidCallback onTap1, onTap2;

  const _HeaderArea({
    required this.p1,
    required this.p2,
    required this.s1,
    required this.s2,
    required this.onTap1,
    required this.onTap2,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          // Left team-colour gradient
          if (p1 != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: w * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      p1!.teamColor.withOpacity(0.35),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          // Right team-colour gradient
          if (p2 != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: w * 0.55,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      p2!.teamColor.withOpacity(0.35),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
          // Foreground
          Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                        child: _PlayerChip(
                            player: p1, slot: 1, season: s1, onTap: onTap1)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _PlayerChip(
                            player: p2, slot: 2, season: s2, onTap: onTap2)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _PlayerPhoto(player: p1, alignRight: true)),
                    const SizedBox(
                      width: 56,
                      child: Center(
                        child: Text('VS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            )),
                      ),
                    ),
                    Expanded(
                        child: _PlayerPhoto(player: p2, alignRight: false)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlayerChip extends StatelessWidget {
  final ComparisonPlayer? player;
  final int slot;
  final String? season;
  final VoidCallback onTap;

  const _PlayerChip({
    required this.player,
    required this.slot,
    required this.season,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            if (player != null) ...[
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    color: Colors.black, shape: BoxShape.circle),
                child: Center(
                  child: Text('${player!.number}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  player!.shortName,
                  style: Body1_b.style.copyWith(color: Colors.black),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Expanded(
                child: Text('PLAYER $slot',
                    style: Body1_b.style.copyWith(color: Colors.black)),
              ),
            const Icon(Icons.keyboard_arrow_down,
                color: Colors.black, size: 24),
          ],
        ),
      ),
    );
  }
}

class _PlayerPhoto extends StatelessWidget {
  final ComparisonPlayer? player;
  final bool alignRight;

  const _PlayerPhoto({required this.player, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignRight ? Alignment.bottomRight : Alignment.bottomLeft,
      child: player == null
          ? SizedBox(
              child: SvgPicture.asset(
                'playerSilhouette.svg',
                width: 130,
                height: 130,
              ),
            )
          : Container(
              width: 130,
              padding: EdgeInsets.only(
                right: alignRight ? 8 : 0,
                left: alignRight ? 0 : 8,
              ),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      player!.teamColor.withOpacity(0.08),
                      player!.teamColor.withOpacity(0.20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: player!.teamColor.withOpacity(0.25), width: 1),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${player!.number}',
                      style: TextStyle(
                        color: player!.teamColor,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        player!.fullName.split(' ').last,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// MOST COMPARED SECTION  (landing state)

class _MostComparedSection extends StatelessWidget {
  final void Function(ComparisonPlayer, ComparisonPlayer) onTapPair;

  const _MostComparedSection({required this.onTapPair});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MOST COMPARED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
              )),
          const SizedBox(height: 14),
          ..._kMostCompared.map((pair) {
            final p1 = _findById(pair[0]);
            final p2 = _findById(pair[1]);
            if (p1 == null || p2 == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ComparisonCard(
                  p1: p1, p2: p2, onTap: () => onTapPair(p1, p2)),
            );
          }),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final ComparisonPlayer p1, p2;
  final VoidCallback onTap;

  const _ComparisonCard(
      {required this.p1, required this.p2, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 130,
          color: const Color(0xFF1A1A1A),
          child: Stack(
            children: [
              // Left colour-wash
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              p1.teamColor.withOpacity(0.45),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              p2.teamColor.withOpacity(0.45),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  // Photo row
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                            child: _CardAvatar(player: p1, alignRight: true)),
                        const SizedBox(
                          width: 48,
                          child: Center(
                            child: Text('VS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                )),
                          ),
                        ),
                        Expanded(
                            child: _CardAvatar(player: p2, alignRight: false)),
                      ],
                    ),
                  ),
                  // Name strip
                  Container(
                    color: Colors.black.withOpacity(0.55),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p1.fullName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                              Text('${p1.team} • #${p1.number}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(p2.fullName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right),
                              Text('${p2.team} • #${p2.number}',
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardAvatar extends StatelessWidget {
  final ComparisonPlayer player;
  final bool alignRight;

  const _CardAvatar({required this.player, required this.alignRight});

  @override
  Widget build(BuildContext context) {
    final initials = player.fullName.split(' ').map((e) => e[0]).take(2).join();
    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          right: alignRight ? 10 : 0,
          left: alignRight ? 0 : 10,
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: player.teamColor.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: player.teamColor.withOpacity(0.35), width: 1.5),
          ),
          child: Center(
            child: Text(initials,
                style: TextStyle(
                  color: player.teamColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      ),
    );
  }
}

// COMPARISON CONTENT  (radar + stat bars)

class _ComparisonContent extends StatelessWidget {
  final ComparisonPlayer p1, p2;

  static const Color _blue = Color(0xFF4A90D9);
  static const Color _orange = Color(0xFFE8622A);

  const _ComparisonContent({required this.p1, required this.p2});

  String _abbrev(String name) => name.split(' ').map((e) => e[0]).join('. ');

  List<_MergedCategory> _mergeCategories() {
    final map = <String, _MergedCategory>{};
    for (final c in p1.statCategories) {
      map[c.label] =
          _MergedCategory(label: c.label, rows1: c.rows, rows2: const []);
    }
    for (final c in p2.statCategories) {
      if (map.containsKey(c.label)) {
        map[c.label] = _MergedCategory(
          label: c.label,
          rows1: map[c.label]!.rows1,
          rows2: c.rows,
        );
      } else {
        map[c.label] =
            _MergedCategory(label: c.label, rows1: const [], rows2: c.rows);
      }
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Radar chart
          SizedBox(
            height: 280,
            child: RadarChart(
              values1: p1.radarValues,
              values2: p2.radarValues,
              labels: _kRadarLabels,
              color1: _blue,
              color2: _orange,
            ),
          ),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: _blue, label: _abbrev(p1.fullName)),
              const SizedBox(width: 20),
              _LegendDot(color: _orange, label: _abbrev(p2.fullName)),
            ],
          ),
          const SizedBox(height: 24),
          // Stat categories
          ..._mergeCategories().map(
            (cat) => _StatCategoryCard(cat: cat),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MergedCategory {
  final String label;
  final List<CompStatRow> rows1, rows2;

  const _MergedCategory(
      {required this.label, required this.rows1, required this.rows2});
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}

class _StatCategoryCard extends StatelessWidget {
  final _MergedCategory cat;

  static const Color _blue = Color(0xFF4A90D9);
  static const Color _orange = Color(0xFFE8622A);

  const _StatCategoryCard({required this.cat});

  @override
  Widget build(BuildContext context) {
    // Build a unified ordered list of stat names
    final seen = <String>{};
    final names = <String>[];
    for (final r in [...cat.rows1, ...cat.rows2]) {
      if (seen.add(r.name)) names.add(r.name);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cat.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              )),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: names.map((name) {
                CompStatRow? r1, r2;
                for (final r in cat.rows1) {
                  if (r.name == name) {
                    r1 = r;
                    break;
                  }
                }
                for (final r in cat.rows2) {
                  if (r.name == name) {
                    r2 = r;
                    break;
                  }
                }
                r1 ??= CompStatRow(name: name, value: 0, display: '0');
                r2 ??= CompStatRow(name: name, value: 0, display: '0');

                final total = r1.value + r2.value;
                final frac1 =
                    total > 0 ? (r1.value / total).clamp(0.05, 0.95) : 0.5;
                final frac2 =
                    total > 0 ? (r2.value / total).clamp(0.05, 0.95) : 0.5;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: SizedBox(
                          height: 34,
                          child: LayoutBuilder(builder: (_, c) {
                            final w = c.maxWidth;
                            return Stack(
                              children: [
                                // Blue bar – left anchor
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: w * frac1,
                                  child: Container(
                                    color: _blue,
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.only(left: 10),
                                    child: Text(r1!.display,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        )),
                                  ),
                                ),
                                // Orange bar – right anchor
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: w * frac2,
                                  child: Container(
                                    color: _orange,
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 10),
                                    child: Text(r2!.display,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        )),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// RADAR CHART

class RadarChart extends StatelessWidget {
  final List<double> values1, values2;
  final List<String> labels;
  final Color color1, color2;

  const RadarChart({
    super.key,
    required this.values1,
    required this.values2,
    required this.labels,
    required this.color1,
    required this.color2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RadarPainter(
        values1: values1,
        values2: values2,
        labels: labels,
        color1: color1,
        color2: color2,
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values1, values2;
  final List<String> labels;
  final Color color1, color2;

  static const int _n = 6;
  static const double _startAngle = -math.pi / 2;

  _RadarPainter({
    required this.values1,
    required this.values2,
    required this.labels,
    required this.color1,
    required this.color2,
  });

  Offset _pt(Offset center, double r, int i) {
    final a = _startAngle + (2 * math.pi * i / _n);
    return Offset(center.dx + r * math.cos(a), center.dy + r * math.sin(a));
  }

  Path _ring(Offset center, double r) {
    final path = Path();
    for (int i = 0; i < _n; i++) {
      final v = _pt(center, r, i);
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    return path..close();
  }

  Path _valueShape(Offset center, double r, List<double> vals) {
    final path = Path();
    for (int i = 0; i < _n; i++) {
      final v = _pt(center, r * vals[i].clamp(0.0, 1.0), i);
      i == 0 ? path.moveTo(v.dx, v.dy) : path.lineTo(v.dx, v.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 38;

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 0.8;

    // Background rings
    for (int i = 1; i <= 5; i++) {
      canvas.drawPath(_ring(center, radius * i / 5), gridPaint);
    }

    // Axis lines
    for (int i = 0; i < _n; i++) {
      canvas.drawLine(center, _pt(center, radius, i), axisPaint);
    }

    // Player 1
    canvas.drawPath(
      _valueShape(center, radius, values1),
      Paint()
        ..color = color1.withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _valueShape(center, radius, values1),
      Paint()
        ..color = color1
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Player 2
    canvas.drawPath(
      _valueShape(center, radius, values2),
      Paint()
        ..color = color2.withOpacity(0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      _valueShape(center, radius, values2),
      Paint()
        ..color = color2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length && i < _n; i++) {
      final pos = _pt(center, radius + 22, i);
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(color: Colors.white60, fontSize: 11),
      );
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.values1 != values1 ||
      old.values2 != values2 ||
      old.color1 != color1 ||
      old.color2 != color2;
}

// PLAYER PICKER BOTTOM SHEET

class _PlayerPickerSheet extends StatefulWidget {
  final int slot;
  final String? excludedId;
  final void Function(ComparisonPlayer) onPick;

  const _PlayerPickerSheet({
    required this.slot,
    this.excludedId,
    required this.onPick,
  });

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  String _query = '';

  List<ComparisonPlayer> get _filtered => kComparisonPlayers
      .where((p) => p.id != widget.excludedId)
      .where((p) =>
          p.fullName.toLowerCase().contains(_query.toLowerCase()) ||
          p.team.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Row(
                children: [
                  const Spacer(),
                  Text('Select Player ${widget.slot}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            // Search box
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search players...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF2C2C2E),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => _query = ''),
                          child: const Icon(Icons.close,
                              color: Colors.white54, size: 18),
                        )
                      : null,
                ),
              ),
            ),
            // Player list
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: Color(0xFF2C2C2E), height: 1),
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: p.teamColor.withOpacity(0.18),
                      child: Text(
                        p.fullName.split(' ').map((e) => e[0]).take(2).join(),
                        style: TextStyle(
                          color: p.teamColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(p.fullName,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text('${p.team} • #${p.number}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white54),
                    onTap: () => widget.onPick(p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// SEASON PICKER BOTTOM SHEET

class _SeasonPickerSheet extends StatelessWidget {
  final ComparisonPlayer player;
  final void Function(String) onPick;

  const _SeasonPickerSheet({required this.player, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
              child: Row(
                children: [
                  const Spacer(),
                  Text(player.fullName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
            // Club + seasons list
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: player.clubSeasons.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Club header
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              margin: const EdgeInsets.only(right: 10),
                              decoration: BoxDecoration(
                                color: player.teamColor.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  entry.key[0],
                                  style: TextStyle(
                                    color: player.teamColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            Text(entry.key.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  letterSpacing: 0.5,
                                )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Season chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((season) {
                            return GestureDetector(
                              onTap: () => onPick(season),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(season,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF2C2C2E), height: 1),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
