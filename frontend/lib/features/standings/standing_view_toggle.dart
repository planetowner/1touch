part of 'standing_features.dart';

enum StandingView { standing, xgTable, bracket }

extension StandingViewLabel on StandingView {
  String get label {
    switch (this) {
      case StandingView.standing:
        return 'STANDING';
      case StandingView.xgTable:
        return 'XG TABLE';
      case StandingView.bracket:
        return 'BRACKET';
    }
  }
}

class StandingViewToggle extends StatelessWidget {
  final StandingView selectedView;
  final List<StandingView> availableViews;
  final List<StandingView> displayedViews;
  final ValueChanged<StandingView> onChanged;

  const StandingViewToggle({
    super.key,
    required this.selectedView,
    required this.availableViews,
    this.displayedViews = const [
      StandingView.standing,
      StandingView.xgTable,
    ],
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    final trackBackground = isDark ? AppPalette.lightGrey : AppPalette.white;
    const selectedBackground = AppPalette.black;
    final trackBorder = isDark ? AppPalette.lightGrey : appColors.divider;
    final selectedIndex = displayedViews.indexOf(selectedView);
    final segmentCount = displayedViews.length;
    final indicatorAlignment = segmentCount <= 1
        ? Alignment.center
        : Alignment(
            -1 + (2 * selectedIndex / (segmentCount - 1)),
            0,
          );

    return Container(
      key: const ValueKey('standing-view-toggle'),
      height: 43,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: trackBackground,
        border: Border.all(width: 2, color: trackBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            key: const ValueKey('standing-view-indicator'),
            alignment: indicatorAlignment,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / segmentCount,
              heightFactor: 1,
              child: DecoratedBox(
                key: const ValueKey('standing-view-indicator-surface'),
                decoration: BoxDecoration(
                  color: selectedBackground,
                  borderRadius: _segmentRadius(selectedIndex, segmentCount),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var index = 0; index < displayedViews.length; index++)
                Expanded(
                  child: _StandingViewSegment(
                    view: displayedViews[index],
                    isSelected: selectedView == displayedViews[index],
                    isEnabled: availableViews.contains(displayedViews[index]),
                    borderRadius: _segmentRadius(index, segmentCount),
                    onTap: () => onChanged(displayedViews[index]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  BorderRadius _segmentRadius(int index, int count) {
    if (count <= 1) return BorderRadius.circular(8);
    if (index == 0) {
      return const BorderRadius.horizontal(left: Radius.circular(8));
    }
    if (index == count - 1) {
      return const BorderRadius.horizontal(right: Radius.circular(8));
    }
    return BorderRadius.zero;
  }
}

class _StandingViewSegment extends StatelessWidget {
  const _StandingViewSegment({
    required this.view,
    required this.isSelected,
    required this.isEnabled,
    required this.borderRadius,
    required this.onTap,
  });

  final StandingView view;
  final bool isSelected;
  final bool isEnabled;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final segmentName = switch (view) {
      StandingView.standing => 'standing',
      StandingView.xgTable => 'xg-table',
      StandingView.bracket => 'bracket',
    };
    final foreground = isSelected
        ? AppPalette.white
        : isEnabled
            ? Theme.of(context).colorScheme.onSurface
            : appColors.mutedForeground;

    return Semantics(
      button: true,
      selected: isSelected,
      enabled: isEnabled,
      child: Material(
        key: ValueKey('standing-view-$segmentName-surface'),
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('standing-view-$segmentName'),
          borderRadius: borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          onTap: isEnabled ? onTap : null,
          child: Container(
            key: ValueKey('standing-view-$segmentName-content'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            alignment: Alignment.center,
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              style: Body2_b.style.copyWith(
                color: foreground,
                height: 1.3,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              child: Text(
                tr(context, view.label),
                maxLines: 1,
                textAlign: TextAlign.center,
                textHeightBehavior: const TextHeightBehavior(
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
