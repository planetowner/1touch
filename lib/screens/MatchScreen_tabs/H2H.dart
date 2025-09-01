import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onetouch/core/stylesheet_dark.dart';

class H2HTab extends StatelessWidget {
  const H2HTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownRow(),
          const SizedBox(height: 16),
          _buildWDLBox(),
          const SizedBox(height: 32),
          _buildPredictionBar('Expert', [60, 20, 20],
              [Color(0xFFFF5B5B), Color(0xFF3D3D3D), Color(0xFF5B92FF)]),
          _buildPredictionBar('User', [50, 30, 20],
              [Color(0xFFFF5B5B), Color(0xFF3D3D3D), Color(0xFF5B92FF)]),
          const Padding(
            padding: EdgeInsets.only(bottom: 8, top: 40),
            child: Text('PAST MATCHES', style: Body2_b.style),
          ),
          ...List.generate(
            5,
                (i) => _buildPastMatchCard('ABC', 'DEF', '#', '#', 'League / Round'),
          ),
          const SizedBox(height: 140),
        ],
      ),
    );
  }

  Widget _buildDropdownRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Color(0xFF3D3D3D),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: const [
                Text('LAST FIVE MATCHES', style: Body2_b.style),
                Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
            ),
          ),
          const Text('AGAINST', style: Body2_b.style),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: SvgPicture.asset(
              'assets/girona_logo.svg',
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWDLBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Color(0xFF3D3D3D),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWDLStat('5', 'Win'),
          _buildWDLStat('3', 'Draw'),
          _buildWDLStat('2', 'Lose'),
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

  Widget _buildPredictionBar(String title, List<int> values, List<Color> colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: Body2_b.style),
          const SizedBox(height: 16),
          Row(
            children: List.generate(values.length, (i) {
              return Expanded(
                flex: values[i],
                child: Container(
                  height: 26,
                  color: colors[i],
                  alignment: Alignment.center,
                  child: Text('${values[i]}%', style: Heading4.style),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildPastMatchCard(
      String teamA, String teamB, String homeScore, String awayScore, String league) {
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
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black,
                child: Icon(Icons.shield, color: Colors.white),
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
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.black,
                child: Icon(Icons.shield, color: Colors.white),
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