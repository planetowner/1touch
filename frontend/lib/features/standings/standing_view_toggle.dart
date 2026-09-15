part of 'standing_features.dart';

enum StandingView { standing, xgTable }

extension StandingViewLabel on StandingView {
  String get label {
    switch (this) {
      case StandingView.standing:
        return 'STANDING';
      case StandingView.xgTable:
        return 'XG TABLE';
    }
  }
}

class StandingViewToggle extends StatelessWidget {
  final StandingView selectedView;
  final List<StandingView> availableViews;
  final ValueChanged<StandingView> onChanged;

  const StandingViewToggle({
    super.key,
    required this.selectedView,
    required this.availableViews,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appColors = AppColors.of(context);
    final trackBackground = isDark ? AppPalette.lightGrey : AppPalette.white;

    return Container(
      key: const ValueKey('standing-view-toggle'),
      height: 42,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: trackBackground,
        border: Border.all(
          color: isDark ? AppPalette.lightGrey : appColors.divider,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(2),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            key: const ValueKey('standing-view-indicator'),
            alignment: selectedView == StandingView.standing
                ? Alignment.centerLeft
                : Alignment.centerRight,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: const FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: DecoratedBox(
                key: ValueKey('standing-view-indicator-surface'),
                decoration: BoxDecoration(
                  color: AppPalette.black,
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
              ),
            ),
          ),
          Row(
            children: StandingView.values
                .map(
                  (view) => Expanded(
                    child: _StandingViewSegment(
                      view: view,
                      isSelected: selectedView == view,
                      isEnabled: availableViews.contains(view),
                      onTap: () => onChanged(view),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _StandingViewSegment extends StatelessWidget {
  const _StandingViewSegment({
    required this.view,
    required this.isSelected,
    required this.isEnabled,
    required this.onTap,
  });

  final StandingView view;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final appColors = AppColors.of(context);
    final segmentName = view == StandingView.standing ? 'standing' : 'xg-table';
    const borderRadius = BorderRadius.all(Radius.circular(6));
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
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              style: Body2_b.style.copyWith(color: foreground),
              child: Text(view.label),
            ),
          ),
        ),
      ),
    );
  }
}
