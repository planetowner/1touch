part of 'player_comparison_screen.dart';

class _ComparisonContent extends StatelessWidget {
  final ComparisonPlayer p1, p2;

  static const Color _blue = Color(0xFF199FD6);
  static const Color _orange = Color(0xFFD64F19);

  const _ComparisonContent({required this.p1, required this.p2});

  String _abbrev(String name) => name.split(' ').map((e) => e[0]).join('. ');

  List<_MergedCategory> _mergeCategories() {
    final map = <String, _MergedCategory>{};
    for (final category in p1.statCategories) {
      map[category.label] = _MergedCategory(
        label: category.label,
        rows1: category.rows,
        rows2: const [],
      );
    }
    for (final category in p2.statCategories) {
      final existing = map[category.label];
      map[category.label] = _MergedCategory(
        label: category.label,
        rows1: existing?.rows1 ?? const [],
        rows2: category.rows,
      );
    }
    return map.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final mutedForeground = AppColors.of(context).mutedForeground;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              height: 238,
              child: RadarChart(
                values1: p1.radarValues,
                values2: p2.radarValues,
                labels: _kRadarLabels,
                color1: _blue,
                color2: _orange,
                gridColor: foreground.withValues(alpha: 0.30),
                labelColor: foreground,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(
                color: _blue,
                label: _abbrev(p1.fullName),
                textColor: mutedForeground,
              ),
              const SizedBox(width: 20),
              _LegendDot(
                color: _orange,
                label: _abbrev(p2.fullName),
                textColor: mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ..._mergeCategories().map((cat) => _StatCategoryCard(cat: cat)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MergedCategory {
  final String label;
  final List<CompStatRow> rows1, rows2;

  const _MergedCategory({
    required this.label,
    required this.rows1,
    required this.rows2,
  });
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color textColor;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });

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
        Text(
          label,
          style: TextStyle(color: textColor, fontSize: 12),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final appColors = AppColors.of(context);
    final names = <String>{...cat.rows1.map((row) => row.name)};
    names.addAll(cat.rows2.map((row) => row.name));

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cat.label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: ValueKey('comparison-stat-card-${cat.label}'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children:
                  names.map((name) => _buildStatRow(name, appColors)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String name, AppColors appColors) {
    final r1 = _findRow(cat.rows1, name);
    final r2 = _findRow(cat.rows2, name);
    final total = r1.value + r2.value;
    final frac1 = total > 0 ? (r1.value / total).clamp(0.05, 0.95) : 0.5;
    final frac2 = total > 0 ? (r2.value / total).clamp(0.05, 0.95) : 0.5;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              color: appColors.mutedForeground,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 34,
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final width = constraints.maxWidth;
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: width * frac1,
                        child: Container(
                          color: _blue,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 10),
                          child: _StatValue(value: r1.display),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: width * frac2,
                        child: Container(
                          color: _orange,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 10),
                          child: _StatValue(value: r2.display),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  CompStatRow _findRow(List<CompStatRow> rows, String name) {
    for (final row in rows) {
      if (row.name == name) return row;
    }
    return CompStatRow(name: name, value: 0, display: '0');
  }
}

class _StatValue extends StatelessWidget {
  final String value;

  const _StatValue({required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }
}
