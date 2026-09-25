import 'package:flutter/material.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';

class AppSegmentedToggleOption<T> {
  const AppSegmentedToggleOption({
    required this.value,
    required this.label,
    this.enabled = true,
    this.surfaceKey,
    this.tapKey,
    this.contentKey,
  });

  final T value;
  final String label;
  final bool enabled;
  final Key? surfaceKey;
  final Key? tapKey;
  final Key? contentKey;
}

/// Shared connected toggle used throughout the app.
///
/// Dark mode uses a black selected segment. Light mode uses Light Mode Dark
/// Grey so the same control remains visible against the white track.
class AppSegmentedToggle<T> extends StatelessWidget {
  static const double _height = 14 * 1.3 + 16;

  const AppSegmentedToggle({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.containerKey,
    this.indicatorKey,
    this.indicatorSurfaceKey,
  }) : assert(options.length > 0);

  final T value;
  final List<AppSegmentedToggleOption<T>> options;
  final ValueChanged<T> onChanged;
  final Key? containerKey;
  final Key? indicatorKey;
  final Key? indicatorSurfaceKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = options.indexWhere((option) => option.value == value);
    final resolvedIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final segmentCount = options.length;
    final indicatorAlignment = segmentCount == 1
        ? Alignment.center
        : Alignment(-1 + (2 * resolvedIndex / (segmentCount - 1)), 0);
    final trackBackground = isDark ? AppPalette.lightGrey : AppPalette.white;
    final selectedBackground =
        isDark ? AppPalette.black : AppPalette.lightModeDarkGrey;
    final selectedForeground = isDark ? AppPalette.white : AppPalette.black;

    return Container(
      key: containerKey,
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: trackBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            key: indicatorKey,
            alignment: indicatorAlignment,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / segmentCount,
              heightFactor: 1,
              child: DecoratedBox(
                key: indicatorSurfaceKey,
                decoration: BoxDecoration(
                  color: selectedBackground,
                  border: Border.all(width: 2, color: trackBackground),
                  borderRadius: _segmentRadius(resolvedIndex, segmentCount),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var index = 0; index < options.length; index++)
                Expanded(
                  child: _AppSegment<T>(
                    option: options[index],
                    selected: index == resolvedIndex,
                    foreground: selectedForeground,
                    borderRadius: _segmentRadius(index, segmentCount),
                    onChanged: onChanged,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static BorderRadius _segmentRadius(int index, int count) {
    if (count == 1) return BorderRadius.circular(8);
    if (index == 0) {
      return const BorderRadius.horizontal(left: Radius.circular(8));
    }
    if (index == count - 1) {
      return const BorderRadius.horizontal(right: Radius.circular(8));
    }
    return BorderRadius.zero;
  }
}

class _AppSegment<T> extends StatelessWidget {
  const _AppSegment({
    required this.option,
    required this.selected,
    required this.foreground,
    required this.borderRadius,
    required this.onChanged,
  });

  final AppSegmentedToggleOption<T> option;
  final bool selected;
  final Color foreground;
  final BorderRadius borderRadius;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final textColor =
        option.enabled ? foreground : AppColors.of(context).mutedForeground;

    return Semantics(
      button: true,
      selected: selected,
      enabled: option.enabled,
      child: Material(
        key: option.surfaceKey,
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: option.tapKey,
          borderRadius: borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          onTap: option.enabled ? () => onChanged(option.value) : null,
          child: Container(
            key: option.contentKey,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: borderRadius,
            ),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOut,
              style: Body2_b.style.copyWith(
                color: textColor,
                height: 1.3,
                leadingDistribution: TextLeadingDistribution.even,
              ),
              child: Text(
                option.label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: Body2_b.style.copyWith(
                  color: textColor,
                  height: 1.3,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
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
