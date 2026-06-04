import 'package:flutter/material.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/models/fixture.dart';
import 'package:onetouch/models/mock_data.dart';
import 'package:intl/intl.dart';

class H2HTab extends StatefulWidget {
  final Fixture fixture;

  const H2HTab({super.key, required this.fixture});

  @override
  State<H2HTab> createState() => _H2HTabState();
}

class _H2HTabState extends State<H2HTab> {

  int _selectedMatches = 5;
  final List<int> _matchOptions = [5, 10, 20];

  Widget build(BuildContext context) {
    final homeId = widget.fixture.homeTeamId;
    final awayId = widget.fixture.awayTeamId;

    // All past H2H fixtures between these two teams
    final allH2H = mockFixtures.where((f) =>
    f.status == FixtureStatus.past &&
        ((f.homeTeamId == homeId && f.awayTeamId == awayId) ||
            (f.homeTeamId == awayId && f.awayTeamId == homeId))
    ).toList()
      ..sort((a, b) => b.startingAt.compareTo(a.startingAt)); // newest first

    final h2hMatches = allH2H.take(_selectedMatches).toList();

    // WDL from home team's perspective
    int wins = 0, draws = 0, losses = 0;
    for (final f in h2hMatches) {
      final hs = f.homeScore ?? 0;
      final as_ = f.awayScore ?? 0;
      final homeIsOurHome = f.homeTeamId == homeId;
      if (hs == as_) {
        draws++;
      } else if ((hs > as_ && homeIsOurHome) || (as_ > hs && !homeIsOurHome)) {
        wins++;
      } else {
        losses++;
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 48),
          _buildDropdownRow(),
          const SizedBox(height: 48),
          _buildWDLBox(wins, draws, losses),
          const SizedBox(height: 48),
          _buildBetsCard(),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 40),
            child: Text('PAST MATCHES', style: Body2_b.style),
          ),
          ...h2hMatches.map((f) {
            final home = mockTeamById(f.homeTeamId);
            final away = mockTeamById(f.awayTeamId);
            final league = mockLeagueById(f.leagueId);
            return _buildPastMatchCard(
              home.shortCode ?? home.name,
              away.shortCode ?? away.name,
              home.imagePath ?? '',
              away.imagePath ?? '',
              f.homeScore?.toString() ?? '-',
              f.awayScore?.toString() ?? '-',
              '${league.name} · ${f.roundName}',
            );
          }),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildDropdownRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Functional dropdown
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF3D3D3D),
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicWidth(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedMatches,
                  dropdownColor: const Color(0xFF3D3D3D),
                  borderRadius: BorderRadius.circular(16),
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ),
                  style: Body2_b.style,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMatches = val);
                  },
                  items: _matchOptions.map((n) {
                    return DropdownMenuItem<int>(
                      value: n,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text('LAST $n MATCHES', style: Body2_b.style),
                      ),
                    );
                  }).toList(),
                  selectedItemBuilder: (context) => _matchOptions.map((n) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'LAST $_selectedMatches MATCHES',
                          style: Body2_b.style,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const Text('AGAINST', style: Body2_b.style),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: Image.network(
                    mockTeamById(widget.fixture.awayTeamId).imagePath ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset('TeamLogos/RealMadrid.png', fit: BoxFit.contain),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWDLBox(int wins, int draws, int losses) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWDLStat('$wins', 'Win'),
          _buildWDLStat('$draws', 'Draw'),
          _buildWDLStat('$losses', 'Lose'),
        ],
      ),
    );
  }

  Widget _buildWDLStat(String value, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Color(0xFF272828),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(value, style: Heading2.style),
        ),
        const SizedBox(height: 4),
        Text(label, style: Body1.style),
      ],
    );
  }

  Widget _buildBetsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'BETS',
          style: Body2_b.style,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EXPERT row
              Row(
                children: const [
                  Text('EXPERT', style: Body2_b.style),
                  SizedBox(width: 6),
                  Icon(Icons.help_outline, color: Colors.white, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              _buildBar(
                values: [60, 20, 20],
                showCheckOnFirst: false,
              ),
              const SizedBox(height: 20),
              // USER row
              const Text('USER', style: Body2_b.style),
              const SizedBox(height: 12),
              _buildBar(
                values: [60, 30, 10],
                showCheckOnFirst: true,
              ),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBar(
      {required List<int> values, required bool showCheckOnFirst}) {
    const radius = Radius.circular(6);
    final segments = [
      // [value, isFirst, isLast, isWhite]
      (values[0], true, false, false),
      (values[1], false, false, false),
      (values[2], false, true, true),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: List.generate(segments.length, (i) {
          final (value, isFirst, isLast, isWhite) = segments[i];
          return Expanded(
            flex: value,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: isWhite
                    ? Colors.white
                    : i == 0
                    ? const Color(0xFFFF5B5B)
                    : const Color(0xFF272828),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$value%',
                    style: Body2_b.style.copyWith(
                      color: isWhite ? Colors.black : null, // If false, 'null' keeps the default Body2_b color
                    ),
                  ),

                  if (i == 0 && showCheckOnFirst)
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPastMatchCard(String teamA, String teamB, String logoA,
      String logoB, String homeScore, String awayScore, String league) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipOval(
                child: Image.network(
                  logoA,
                  width: 32, height: 32, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Image.asset('TeamLogos/Barcelona.png', width: 32, height: 32),
                ),
              ),
              const SizedBox(width: 8),
              Text(teamA, style: Heading5.style),
              const Spacer(),
              _scoreBox(homeScore),
              const SizedBox(width: 8),
              _scoreBox(awayScore),
              const Spacer(),
              Text(teamB, style: Heading5.style),
              const SizedBox(width: 8),
              ClipOval(
                child: Image.network(
                  logoB,
                  width: 32, height: 32, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      Image.asset('TeamLogos/RealMadrid.png', width: 32, height: 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(league, style: Body2.style),
        ],
      ),
    );
  }

  Widget _scoreBox(String score) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF272828),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(score, style: Heading2.style),
    );
  }
}