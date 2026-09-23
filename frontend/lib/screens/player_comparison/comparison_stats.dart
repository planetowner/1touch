part of 'player_comparison_screen.dart';

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({required this.p1, required this.p2});
  final PlayerDetail p1, p2;

  String _abbrev(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .join('. ');

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final muted = AppColors.of(context).mutedForeground;
    final colors = _comparisonColors(context, p1, p2);
    final categories = _mergeCategories(
      p1.analysis?.categories ?? const [],
      p2.analysis?.categories ?? const [],
    );

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
              child: _AttributeUnavailable(foreground: foreground),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: _LegendDot(
                  color: colors.anchor,
                  label: _abbrev(p1.profile.name),
                  textColor: muted,
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: _LegendDot(
                  color: colors.opponent,
                  label: _abbrev(p2.profile.name),
                  textColor: muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          for (final category in categories)
            _StatCategoryCard(
              category: category,
              firstColor: colors.anchor,
              secondColor: colors.opponent,
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AttributeUnavailable extends StatelessWidget {
  const _AttributeUnavailable({required this.foreground});
  final Color foreground;

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _EmptyRadarPainter(
                locale: Localizations.localeOf(context),
                color: foreground.withValues(alpha: .30),
                labelColor: foreground,
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surface
                    .withValues(alpha: .92),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tr(context, "Coming soon"),
                key: const ValueKey('comparison-attribute-pending'),
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      );
}

class _MergedCategory {
  const _MergedCategory({
    required this.label,
    required this.first,
    required this.second,
  });
  final String label;
  final List<PlayerSeasonMetric> first, second;
}

List<_MergedCategory> _mergeCategories(
  List<PlayerSeasonCategory> first,
  List<PlayerSeasonCategory> second,
) {
  final order = <String>[];
  final firstMap = <String, PlayerSeasonCategory>{};
  final secondMap = <String, PlayerSeasonCategory>{};
  for (final category in first) {
    order.add(category.code);
    firstMap[category.code] = category;
  }
  for (final category in second) {
    if (!order.contains(category.code)) order.add(category.code);
    secondMap[category.code] = category;
  }
  return [
    for (final code in order)
      _MergedCategory(
        label: firstMap[code]?.label ?? secondMap[code]!.label,
        first: firstMap[code]?.metrics ?? const [],
        second: secondMap[code]?.metrics ?? const [],
      ),
  ];
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.textColor,
  });
  final Color color, textColor;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tr(context, label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ),
        ],
      );
}

class _StatCategoryCard extends StatelessWidget {
  const _StatCategoryCard({
    required this.category,
    required this.firstColor,
    required this.secondColor,
  });
  final _MergedCategory category;
  final Color firstColor, secondColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = Theme.of(context).colorScheme.onSurface;
    final names = <String>[];
    for (final metric in [...category.first, ...category.second]) {
      if (!names.contains(metric.metric.code)) names.add(metric.metric.code);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerCategoryLabel(context, category.label).toUpperCase(),
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            key: ValueKey('comparison-stat-card-${category.label}'),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
            decoration: BoxDecoration(
              color: isDark ? AppPalette.darkGrey : AppPalette.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: appCardShadows(context),
            ),
            child: Column(
              children: [
                for (final code in names)
                  _StatRow(
                    code: code,
                    category: category,
                    firstColor: firstColor,
                    secondColor: secondColor,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.code,
    required this.category,
    required this.firstColor,
    required this.secondColor,
  });
  final String code;
  final _MergedCategory category;
  final Color firstColor, secondColor;

  PlayerSeasonMetric? _find(List<PlayerSeasonMetric> rows) {
    for (final row in rows) {
      if (row.metric.code == code) return row;
    }
    return null;
  }

  String _display(double? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(value.abs() < 10 ? 2 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final first = _find(category.first);
    final second = _find(category.second);
    final firstValue = first?.metric.value ?? 0;
    final secondValue = second?.metric.value ?? 0;
    final total = firstValue.abs() + secondValue.abs();
    final firstFraction =
        total == 0 ? .5 : (firstValue.abs() / total).clamp(.05, .95);
    final secondFraction =
        total == 0 ? .5 : (secondValue.abs() / total).clamp(.05, .95);
    final label = first?.metric.label ?? second?.metric.label ?? code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, label),
            style: TextStyle(
              color: AppColors.of(context).mutedForeground,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 34,
              child: LayoutBuilder(
                builder: (_, constraints) => Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * firstFraction,
                      child: Container(
                        color: firstColor,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 10),
                        child: _StatValue(
                          value: _display(first?.metric.value),
                          color: _readableText(firstColor),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: constraints.maxWidth * secondFraction,
                      child: Container(
                        color: secondColor,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 10),
                        child: _StatValue(
                          value: _display(second?.metric.value),
                          color: _readableText(secondColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _readableText(Color background) {
  final black = ColorUtils.getContrastRatio(background, Colors.black);
  final white = ColorUtils.getContrastRatio(background, Colors.white);
  return black >= white ? Colors.black : Colors.white;
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.value, required this.color});
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(
        value,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      );
}
