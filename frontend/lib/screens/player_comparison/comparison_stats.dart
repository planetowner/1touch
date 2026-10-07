part of 'player_comparison_screen.dart';

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({required this.p1, required this.p2});
  final PlayerDetail p1, p2;

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 24),
          Text(tr(context, 'ATTRIBUTES'), style: Body2_b.style),
          const SizedBox(height: 16),
          PlayerSurface(
            key: const ValueKey('comparison-attribute-pending-card'),
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              height: 96,
              child: Center(
                child: Text(
                  tr(context, 'Coming soon'),
                  key: const ValueKey('comparison-attribute-pending'),
                  style: Heading5.style,
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
          for (var index = 0; index < categories.length; index++) ...[
            _StatCategoryCard(
              category: categories[index],
              firstColor: colors.anchor,
              secondColor: colors.opponent,
            ),
            if (index < categories.length - 1) const SizedBox(height: 48),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          playerCategoryLabel(context, category.label).toUpperCase(),
          style: Body2_b.style.copyWith(color: foreground, height: 1.30),
        ),
        const SizedBox(height: 16),
        Container(
          key: ValueKey('comparison-stat-card-${category.label}'),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          decoration: BoxDecoration(
            color: isDark ? AppPalette.darkGrey : AppPalette.white,
            borderRadius: BorderRadius.circular(16),
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

  @override
  Widget build(BuildContext context) {
    final first = _find(category.first);
    final second = _find(category.second);
    final firstStat = playerSeasonStat(first);
    final secondStat = playerSeasonStat(second);
    final stat = first != null ? firstStat : secondStat;
    final total = (firstStat.value ?? 0).abs() + (secondStat.value ?? 0).abs();
    final comparable =
        firstStat.value != null && secondStat.value != null && total > 0;
    // 누락값을 0으로 간주한 비율 대신 중립 배경에 실제 표시값만 보여줘요.
    final neutral = AppColors.of(context).subtleBackground;
    final leftColor = comparable ? firstColor : neutral;
    final rightColor = comparable ? secondColor : neutral;
    final firstLabel = firstStat.text;
    final secondLabel = secondStat.text;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  appStatLabel(context, stat.label),
                  style: Body1_b.style.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    height: 1.30,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(tr(context, stat.unit), style: Eyebrow.style),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 32,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  double minimumWidth(String text) {
                    final painter = TextPainter(
                      text: TextSpan(text: text, style: Heading4.style),
                      textDirection: Directionality.of(context),
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    final width = painter.width.ceilToDouble() + 24 + 1;
                    painter.dispose();
                    return width;
                  }

                  final firstMinimum = minimumWidth(firstLabel);
                  final secondMinimum = minimumWidth(secondLabel);
                  // 두 수치의 절댓값 비율로 막대를 나누되 각 라벨의 실제 너비와
                  // 양쪽 12px 여백을 먼저 보장해 긴 값도 잘리지 않게 해요.
                  final contentWidth = math.max(
                    constraints.maxWidth,
                    firstMinimum + secondMinimum,
                  );
                  final firstWidth = (comparable
                          ? contentWidth * firstStat.value!.abs() / total
                          : contentWidth / 2)
                      .clamp(firstMinimum, contentWidth - secondMinimum)
                      .toDouble();
                  final segments = Row(
                    children: [
                      SizedBox(
                        key: ValueKey('comparison-stat-first-$code'),
                        width: firstWidth,
                        child: Container(
                          color: leftColor,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _StatValue(
                            value: firstLabel,
                            color: _readableText(leftColor),
                          ),
                        ),
                      ),
                      SizedBox(
                        key: ValueKey('comparison-stat-second-$code'),
                        width: contentWidth - firstWidth,
                        child: Container(
                          color: rightColor,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _StatValue(
                            value: secondLabel,
                            color: _readableText(rightColor),
                          ),
                        ),
                      ),
                    ],
                  );
                  if (contentWidth <= constraints.maxWidth) return segments;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(width: contentWidth, child: segments),
                  );
                },
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
        maxLines: 1,
        softWrap: false,
        style: Heading4.style.copyWith(color: color),
      );
}
