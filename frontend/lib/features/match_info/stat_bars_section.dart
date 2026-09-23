part of 'match_info_features.dart';

class StatBarsSection extends StatelessWidget {
  final List<StatBarData> bars;
  final Color homeColor;
  final Color awayColor;

  const StatBarsSection({
    super.key,
    required this.bars,
    this.homeColor = const Color(0xFFFF5C5C),
    this.awayColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bars
          .map(
            (bar) => StatComparisonBar(
              data: bar,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
          )
          .toList(),
    );
  }
}

class StatBarData {
  final String category;
  final double homePercent;
  final double awayPercent;

  /// Percentage stats show "63%"; count stats (shots, corners…) show the
  /// raw value and only use the numbers to proportion the bar.
  final bool isPercent;
  final int? fractionDigits;

  const StatBarData({
    required this.category,
    required this.homePercent,
    required this.awayPercent,
    this.isPercent = true,
    this.fractionDigits,
  });
}

class StatComparisonBar extends StatelessWidget {
  final StatBarData data;
  final Color homeColor;
  final Color awayColor;

  const StatComparisonBar({
    super.key,
    required this.data,
    this.homeColor = const Color(0xFFFF5C5C),
    this.awayColor = Colors.white,
  });

  String _fmt(double v) {
    final number = data.fractionDigits == null
        ? (v % 1 == 0 ? v.toInt().toString() : v.toString())
        : v.toStringAsFixed(data.fractionDigits!);
    return data.isPercent ? '$number%' : number;
  }

  @override
  Widget build(BuildContext context) {
    final total = data.homePercent + data.awayPercent;
    final homeFlex = total == 0 ? 50 : (data.homePercent / total * 100).round();
    final awayFlex = 100 - homeFlex;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Center(
              child: Text(tr(context, data.category).toUpperCase(),
                  style: Body2_b.style)),
          const SizedBox(height: 6),
          Row(
            children: [
              // Fixed-width value columns so every bar spans the same width
              // no matter how many digits the values have.
              SizedBox(
                width: 44,
                child: Text(_fmt(data.homePercent),
                    style: Body2.style, textAlign: TextAlign.left),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: homeFlex,
                        child: Container(
                          key: ValueKey(
                            'match-info-stat-${data.category}-home-fill',
                          ),
                          height: 8,
                          color: homeColor,
                        ),
                      ),
                      Expanded(
                        flex: awayFlex,
                        child: Container(
                          key: ValueKey(
                            'match-info-stat-${data.category}-away-fill',
                          ),
                          height: 8,
                          color: awayColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 44,
                child: Text(_fmt(data.awayPercent),
                    style: Body2.style, textAlign: TextAlign.right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
