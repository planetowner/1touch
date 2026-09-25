import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_segmented_toggle.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  Future<_ToggleSnapshot> render(
    WidgetTester tester,
    ThemeData theme,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 345,
              child: AppSegmentedToggle<bool>(
                containerKey: const ValueKey('toggle'),
                indicatorSurfaceKey: const ValueKey('indicator'),
                value: false,
                options: const [
                  AppSegmentedToggleOption(
                    value: true,
                    label: 'IN',
                    contentKey: ValueKey('in'),
                  ),
                  AppSegmentedToggleOption(
                    value: false,
                    label: 'OUT',
                    contentKey: ValueKey('out'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final root = tester.widget<Container>(find.byKey(const ValueKey('toggle')));
    final unselected =
        tester.widget<Container>(find.byKey(const ValueKey('in')));
    final selected =
        tester.widget<Container>(find.byKey(const ValueKey('out')));
    final selectedText = tester.widget<Text>(find.text('OUT'));
    final indicator = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('indicator')),
    );
    return _ToggleSnapshot(
      size: tester.getSize(find.byKey(const ValueKey('toggle'))),
      rootDecoration: root.decoration! as BoxDecoration,
      unselectedPadding: unselected.padding!,
      selectedPadding: selected.padding!,
      unselectedDecoration: unselected.decoration! as BoxDecoration,
      selectedDecoration: selected.decoration! as BoxDecoration,
      indicatorDecoration: indicator.decoration as BoxDecoration,
      selectedTextColor: selectedText.style!.color!,
    );
  }

  testWidgets('light and dark toggles share geometry and only change colors',
      (tester) async {
    final light = await render(tester, app_style.whitetheme);
    final dark = await render(tester, app_style.darktheme);

    expect(light.size.width, 345);
    expect(light.size.height, closeTo(34.2, 0.01));
    expect(dark.size, light.size);
    expect(light.rootDecoration.borderRadius, BorderRadius.circular(8));
    expect(dark.rootDecoration.borderRadius, light.rootDecoration.borderRadius);
    expect(light.unselectedPadding, const EdgeInsets.all(8));
    expect(light.selectedPadding, const EdgeInsets.all(8));
    expect(dark.unselectedPadding, light.unselectedPadding);
    expect(dark.selectedPadding, light.selectedPadding);
    expect(light.indicatorDecoration.border?.top.width, 2);
    expect(
      dark.indicatorDecoration.border?.top.width,
      light.indicatorDecoration.border?.top.width,
    );

    expect(light.rootDecoration.color, app_style.AppPalette.white);
    expect(light.unselectedDecoration.color, Colors.transparent);
    expect(light.selectedDecoration.color, Colors.transparent);
    expect(
      light.indicatorDecoration.color,
      app_style.AppPalette.lightModeDarkGrey,
    );
    expect(light.selectedTextColor, app_style.AppPalette.black);
    expect(dark.rootDecoration.color, app_style.AppPalette.lightGrey);
    expect(dark.unselectedDecoration.color, Colors.transparent);
    expect(dark.selectedDecoration.color, Colors.transparent);
    expect(dark.indicatorDecoration.color, app_style.AppPalette.black);
    expect(dark.selectedTextColor, app_style.AppPalette.white);
    final outText = tester.widget<Text>(find.text('OUT'));
    expect(outText.textAlign, TextAlign.center);
    expect(outText.overflow, TextOverflow.clip);
  });

  testWidgets('selection slides behind text without moving either label',
      (tester) async {
    var selected = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: app_style.whitetheme,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 345,
              child: StatefulBuilder(
                builder: (context, setState) => AppSegmentedToggle<bool>(
                  value: selected,
                  indicatorSurfaceKey: const ValueKey('indicator'),
                  options: const [
                    AppSegmentedToggleOption(
                      value: true,
                      label: 'IN',
                      tapKey: ValueKey('in-tap'),
                    ),
                    AppSegmentedToggleOption(value: false, label: 'OUT'),
                  ],
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final inCenter = tester.getCenter(find.text('IN'));
    final outCenter = tester.getCenter(find.text('OUT'));
    final indicatorStart =
        tester.getTopLeft(find.byKey(const ValueKey('indicator'))).dx;

    await tester.tap(find.text('OUT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final indicatorMiddle =
        tester.getTopLeft(find.byKey(const ValueKey('indicator'))).dx;
    expect(tester.getCenter(find.text('IN')), inCenter);
    expect(tester.getCenter(find.text('OUT')), outCenter);
    expect(indicatorMiddle, greaterThan(indicatorStart));

    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('IN')), inCenter);
    expect(tester.getCenter(find.text('OUT')), outCenter);
  });
}

class _ToggleSnapshot {
  const _ToggleSnapshot({
    required this.size,
    required this.rootDecoration,
    required this.unselectedPadding,
    required this.selectedPadding,
    required this.unselectedDecoration,
    required this.selectedDecoration,
    required this.indicatorDecoration,
    required this.selectedTextColor,
  });

  final Size size;
  final BoxDecoration rootDecoration;
  final EdgeInsetsGeometry unselectedPadding;
  final EdgeInsetsGeometry selectedPadding;
  final BoxDecoration unselectedDecoration;
  final BoxDecoration selectedDecoration;
  final BoxDecoration indicatorDecoration;
  final Color selectedTextColor;
}
