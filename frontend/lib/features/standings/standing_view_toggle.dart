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
    return AppSegmentedToggle<StandingView>(
      containerKey: const ValueKey('standing-view-toggle'),
      indicatorKey: const ValueKey('standing-view-indicator'),
      indicatorSurfaceKey: const ValueKey('standing-view-indicator-surface'),
      value: selectedView,
      options: [
        for (final view in displayedViews)
          AppSegmentedToggleOption(
            value: view,
            label: tr(context, view.label),
            enabled: availableViews.contains(view),
            surfaceKey: ValueKey(
              'standing-view-${_segmentName(view)}-surface',
            ),
            tapKey: ValueKey('standing-view-${_segmentName(view)}'),
            contentKey: ValueKey(
              'standing-view-${_segmentName(view)}-content',
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }

  String _segmentName(StandingView view) => switch (view) {
        StandingView.standing => 'standing',
        StandingView.xgTable => 'xg-table',
        StandingView.bracket => 'bracket',
      };
}
