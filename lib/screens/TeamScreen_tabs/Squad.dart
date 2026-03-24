import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum SortOption { position, jerseyNumber, age, contractLength }

extension SortOptionLabel on SortOption {
  String get label {
    switch (this) {
      case SortOption.position:
        return 'Position';
      case SortOption.jerseyNumber:
        return 'Jersey Number';
      case SortOption.age:
        return 'Age';
      case SortOption.contractLength:
        return 'Contract Length';
    }
  }
}

enum Position { GK, DF, MF, FW }

class SquadPlayer {
  final int id;
  final String name;
  final String teamLabel;
  final int? jerseyNumber;
  final Position position;
  final int age;
  final String? imageUrl;
  final int contractEndYear;

  const SquadPlayer({
    required this.id,
    required this.name,
    required this.teamLabel,
    this.jerseyNumber,
    required this.position,
    required this.age,
    this.imageUrl,
    required this.contractEndYear,
  });

  factory SquadPlayer.fromJson(Map<String, dynamic> json) {
    return SquadPlayer(
        id: json['id'] as int,
        name: json['name'] as String,
        teamLabel: json['team_label'] as String,
        jerseyNumber: json['jersey_number'] as int?,
        position: _positionFromId(json['position_id'] as int),
        imageUrl: json['image_url'] as String?,
        age: json['age'] as int,
        contractEndYear: json['contractYear'] as int);
  }

  static Position _positionFromId(int id) {
    switch (id) {
      case 24:
        return Position.GK;
      case 25:
        return Position.DF;
      case 26:
        return Position.MF;
      case 27:
        return Position.FW;
      default:
        return Position.MF;
    }
  }
}

List<SquadPlayer> _mockSquad() => const [
      // Goalkeepers
      SquadPlayer(
          id: 1,
          name: 'Kim Seung-gyu',
          teamLabel: 'Jeonbuk • 1',
          jerseyNumber: 1,
          position: Position.GK,
          age: 35,
          contractEndYear: 2025),
      SquadPlayer(
          id: 2,
          name: 'Park Jun-hyuk',
          teamLabel: 'Jeonbuk • 31',
          jerseyNumber: 31,
          position: Position.GK,
          age: 24,
          contractEndYear: 2027),
      SquadPlayer(
          id: 3,
          name: 'Lee Chang-geun',
          teamLabel: 'Jeonbuk • 41',
          jerseyNumber: 41,
          position: Position.GK,
          age: 21,
          contractEndYear: 2026),

      // Defenders
      SquadPlayer(
          id: 4,
          name: 'Hong Jeong-ho',
          teamLabel: 'Jeonbuk • 4',
          jerseyNumber: 4,
          position: Position.DF,
          age: 34,
          contractEndYear: 2025),
      SquadPlayer(
          id: 5,
          name: 'Choi Bo-kyung',
          teamLabel: 'Jeonbuk • 5',
          jerseyNumber: 5,
          position: Position.DF,
          age: 29,
          contractEndYear: 2026),
      SquadPlayer(
          id: 6,
          name: 'Kim Jin-su',
          teamLabel: 'Jeonbuk • 13',
          jerseyNumber: 13,
          position: Position.DF,
          age: 31,
          contractEndYear: 2026),
      SquadPlayer(
          id: 7,
          name: 'Lee Yong',
          teamLabel: 'Jeonbuk • 2',
          jerseyNumber: 2,
          position: Position.DF,
          age: 36,
          contractEndYear: 2025),
      SquadPlayer(
          id: 8,
          name: 'Gu Ja-ryong',
          teamLabel: 'Jeonbuk • 3',
          jerseyNumber: 3,
          position: Position.DF,
          age: 27,
          contractEndYear: 2027),
      SquadPlayer(
          id: 9,
          name: 'Park Jin-seop',
          teamLabel: 'Jeonbuk • 23',
          jerseyNumber: 23,
          position: Position.DF,
          age: 23,
          contractEndYear: 2028),
      SquadPlayer(
          id: 10,
          name: 'Shin Hyung-min',
          teamLabel: 'Jeonbuk • 15',
          jerseyNumber: 15,
          position: Position.DF,
          age: 26,
          contractEndYear: 2027),
      SquadPlayer(
          id: 11,
          name: 'Kim Tae-hyun',
          teamLabel: 'Jeonbuk • 33',
          jerseyNumber: 33,
          position: Position.DF,
          age: 22,
          contractEndYear: 2026),

      // Midfielders
      SquadPlayer(
          id: 12,
          name: 'Baek Seung-ho',
          teamLabel: 'Jeonbuk • 6',
          jerseyNumber: 6,
          position: Position.MF,
          age: 30,
          contractEndYear: 2026),
      SquadPlayer(
          id: 13,
          name: 'Han Kyo-won',
          teamLabel: 'Jeonbuk • 8',
          jerseyNumber: 8,
          position: Position.MF,
          age: 28,
          contractEndYear: 2025),
      SquadPlayer(
          id: 14,
          name: 'Moon Seon-min',
          teamLabel: 'Jeonbuk • 7',
          jerseyNumber: 7,
          position: Position.MF,
          age: 32,
          contractEndYear: 2025),
      SquadPlayer(
          id: 15,
          name: 'Son Jun-ho',
          teamLabel: 'Jeonbuk • 10',
          jerseyNumber: 10,
          position: Position.MF,
          age: 33,
          contractEndYear: 2026),
      SquadPlayer(
          id: 16,
          name: 'Jeong Hyeok',
          teamLabel: 'Jeonbuk • 16',
          jerseyNumber: 16,
          position: Position.MF,
          age: 25,
          contractEndYear: 2027),
      SquadPlayer(
          id: 17,
          name: 'Lee Seung-gi',
          teamLabel: 'Jeonbuk • 22',
          jerseyNumber: 22,
          position: Position.MF,
          age: 24,
          contractEndYear: 2028),
      SquadPlayer(
          id: 18,
          name: 'Kim Bo-kyung',
          teamLabel: 'Jeonbuk • 26',
          jerseyNumber: 26,
          position: Position.MF,
          age: 35,
          contractEndYear: 2025),
      SquadPlayer(
          id: 19,
          name: 'Park Chan-ul',
          teamLabel: 'Jeonbuk • 28',
          jerseyNumber: 28,
          position: Position.MF,
          age: 20,
          contractEndYear: 2027),

      // Forwards
      SquadPlayer(
          id: 20,
          name: 'Cho Gue-sung',
          teamLabel: 'Jeonbuk • 9',
          jerseyNumber: 9,
          position: Position.FW,
          age: 25,
          contractEndYear: 2027),
      SquadPlayer(
          id: 21,
          name: 'Gustav Wikheim',
          teamLabel: 'Jeonbuk • 11',
          jerseyNumber: 11,
          position: Position.FW,
          age: 30,
          contractEndYear: 2026),
      SquadPlayer(
          id: 22,
          name: 'Stanislav Iljutcenko',
          teamLabel: 'Jeonbuk • 17',
          jerseyNumber: 17,
          position: Position.FW,
          age: 34,
          contractEndYear: 2025),
      SquadPlayer(
          id: 23,
          name: 'Lee Dong-jun',
          teamLabel: 'Jeonbuk • 19',
          jerseyNumber: 19,
          position: Position.FW,
          age: 23,
          contractEndYear: 2028),
      SquadPlayer(
          id: 24,
          name: 'Kim In-sung',
          teamLabel: 'Jeonbuk • 29',
          jerseyNumber: 29,
          position: Position.FW,
          age: 21,
          contractEndYear: 2027),
      SquadPlayer(
          id: 25,
          name: 'Park Sang-hyuk',
          teamLabel: 'Jeonbuk • 37',
          jerseyNumber: 37,
          position: Position.FW,
          age: 19,
          contractEndYear: 2028),
    ];

class SquadTab extends StatefulWidget {
  final Map<String, dynamic>? team;

  const SquadTab({super.key, required this.team});

  @override
  State<SquadTab> createState() => _SquadTabState();
}

class _SquadTabState extends State<SquadTab> {
  List<SquadPlayer> _players = [];
  bool _isLoading = true;
  SortOption _sortOption = SortOption.position;
  bool _isAscending = true;
  bool _isDropdownOpen = false;

  static const _positionOrder = [
    Position.GK,
    Position.DF,
    Position.MF,
    Position.FW
  ];

  static String _positionLabel(Position pos) {
    switch (pos) {
      case Position.GK:
        return 'GOALKEEPER';
      case Position.DF:
        return 'DEFENDERS';
      case Position.MF:
        return 'MIDFIELDERS';
      case Position.FW:
        return 'ATTACKERS';
    }
  }

  int _compare(SquadPlayer a, SquadPlayer b) {
    int result;
    switch (_sortOption) {
      case SortOption.position:
      case SortOption.jerseyNumber:
        result = (a.jerseyNumber ?? 999).compareTo(b.jerseyNumber ?? 999);
        break;
      case SortOption.age:
        result = a.age.compareTo(b.age);
        break;
      case SortOption.contractLength:
        result = a.contractEndYear.compareTo(b.contractEndYear);
        break;
    }
    return _isAscending ? result : -result;
  }

  @override
  void initState() {
    super.initState();
    _fetchPlayers();
  }

  Future<void> _fetchPlayers() async {
    // final teamId = widget.team?['id'];
    // final url = Uri.parse('https://YOUR_HOST/api/teams/$teamId/squad');
    // final response = await http.get(url);
    // if (response.statusCode == 200) {
    //   final data = json.decode(response.body);
    //   final squadList = data['squads'] as List;
    //   setState(() {
    //     _players = squadList
    //         .map((item) => SquadPlayer.fromJson(item as Map<String, dynamic>))
    //         .toList();
    //     _isLoading = false;
    //   });
    // }

    await Future.delayed(const Duration(milliseconds: 400)); // simulate network
    setState(() {
      _players = _mockSquad();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    if (_players.isEmpty) {
      return const Center(
        child:
            Text('No players found', style: TextStyle(color: Colors.white70)),
      );
    }

    // Group & sort
    if (_sortOption == SortOption.position) {
      final grouped = <Position, List<SquadPlayer>>{};
      for (final p in _players) {
        grouped.putIfAbsent(p.position, () => []).add(p);
      }
      for (final group in grouped.values) {
        group.sort(_compare);
      }

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          _sortDropdown(),
          ..._positionOrder
              .where((pos) => grouped.containsKey(pos))
              .expand((pos) => [
                    const SizedBox(height: 24),
                    _PositionHeader(label: _positionLabel(pos)),
                    _PlayerGrid(players: grouped[pos]!),
                  ]),
        ],
      );
    }
    final sorted = [..._players]..sort(_compare);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        IntrinsicWidth(
          child: _sortDropdown(),
        ),
        const SizedBox(height: 24),
        _PlayerGrid(players: sorted),
      ],
    );
  }

  Widget _sortDropdown() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDropdownOpen = !_isDropdownOpen),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _sortOption.label.toUpperCase(),
                        style: Body2_b.style,
                      ),
                      AnimatedRotation(
                        turns: _isDropdownOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white, size: 24),
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                child: _isDropdownOpen
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Ascending / Descending
                    _dropdownItem(
                      label: 'ASCENDING',
                      selected: _isAscending,
                      onTap: () => setState(() {
                        _isAscending = true;
                        _isDropdownOpen = false;
                      }),
                    ),
                    _dropdownItem(
                      label: 'DESCENDING',
                      selected: !_isAscending,
                      onTap: () => setState(() {
                        _isAscending = false;
                        _isDropdownOpen = false;
                      }),
                    ),

                    // Divider
                    Container(
                      height: 1,
                      color: const Color(0xFF888888),
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),

                    // Section 2: Sort fields
                    ...SortOption.values.map((option) => _dropdownItem(
                      label: option.label.toUpperCase(),
                      selected: _sortOption == option,
                      onTap: () => setState(() {
                        _sortOption = option;
                        _isDropdownOpen = false;
                      }),
                    )),

                    const SizedBox(height: 4),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dropdownItem({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: selected ? Body2_b.style : Body2_b.style,
            ),
            const SizedBox(width: 8),
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 16)
            else
              const SizedBox(width: 16), // reserve same space as checkmark
          ],
        ),
      ),
    );
  }
}

class _PositionHeader extends StatelessWidget {
  final String label;

  const _PositionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Body2_b.style,
    );
  }
}

class _PlayerGrid extends StatelessWidget {
  final List<SquadPlayer> players;

  const _PlayerGrid({required this.players});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: players.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.79,
      ),
      itemBuilder: (context, index) => _PlayerCard(player: players[index]),
    );
  }
}

class _PlayerCard extends StatelessWidget {
  final SquadPlayer player;

  const _PlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Background + image fills entire area
                Container(
                  width: double.infinity,
                  color: const Color(0xFF272828),
                ),

                // Playerimage
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: player.imageUrl != null
                      ? Image.network(
                          player.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/HeungminSon.png',
                            fit: BoxFit.cover,
                            width: 104,
                          ),
                        )
                      : Image.asset(
                          'assets/HeungminSon.png',
                          fit: BoxFit.cover,
                          width: 104,
                        ),
                ),

                // Jersey badge — top-left overlay
                Positioned(
                  top: 10,
                  left: 10,
                  child: _JerseyBadge(number: player.jerseyNumber),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF3D3D3D),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Heading5.style,
                ),
                const SizedBox(height: 2),
                Text(
                  player.teamLabel,
                  style: Body2.style,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JerseyBadge extends StatelessWidget {
  final int? number;

  const _JerseyBadge({this.number});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number != null ? '#${number!}' : '##',
          style: Heading2.style,
        ),
        // Row(
        //   mainAxisSize: MainAxisSize.min,
        //   children: [
        //     const Icon(Icons.arrow_drop_down, color: Color(0xFFE8003D), size: 24),
        //     Text('#', style: Body2_b.style),
        //   ],
        // ),
      ],
    );
  }
}
