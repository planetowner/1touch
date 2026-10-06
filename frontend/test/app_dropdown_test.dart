import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/app_dropdown.dart';
import 'package:onetouch/core/style.dart';

void main() {
  testWidgets(
      'opens above content with longest-option width and fixed right chevron',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppDropdown<int>(
                  key: const ValueKey('dropdown'),
                  triggerKey: const ValueKey('dropdown-trigger'),
                  chevronKey: const ValueKey('dropdown-chevron'),
                  width: 120,
                  value: 1,
                  backgroundColor: const Color(0xFF3D3D3D),
                  options: const [
                    AppDropdownOption<int>(
                      value: 1,
                      label: 'SHORT',
                      optionKey: ValueKey('short-option'),
                    ),
                    AppDropdownOption<int>(
                      value: 2,
                      label: 'LONG DROPDOWN',
                      optionKey: ValueKey('long-option'),
                    ),
                  ],
                  onChanged: (_) {},
                ),
                const SizedBox(
                  key: ValueKey('content-below'),
                  width: 120,
                  height: 40,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final dropdown = find.byKey(const ValueKey('dropdown'));
    final trigger = find.byKey(const ValueKey('dropdown-trigger'));
    final chevron = find.byKey(const ValueKey('dropdown-chevron'));
    final contentTopBefore = tester.getTopLeft(
      find.byKey(const ValueKey('content-below')),
    );

    expect(tester.getSize(trigger).height, AppDropdownTokens.height);
    expect(tester.getRect(trigger).right - tester.getRect(chevron).right, 8);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('content-below'))),
      contentTopBefore,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('long-option'))).width,
      greaterThan(tester.getSize(dropdown).width),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('long-option'))).left,
      closeTo(tester.getRect(trigger).left, 0.1),
    );
    expect(
      tester.getTopLeft(find.text('SHORT').last).dx,
      tester.getTopLeft(find.text('LONG DROPDOWN')).dx,
    );
    final menuMaterials = tester.widgetList<Material>(
      find.ancestor(
        of: find.byKey(const ValueKey('long-option')),
        matching: find.byType(Material),
      ),
    );
    expect(
      menuMaterials
          .any((material) => material.color == const Color(0xFF3D3D3D)),
      isTrue,
    );
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('custom-height trigger keeps its chevron centered at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AppDropdown<int>(
              triggerKey: const ValueKey('tall-trigger'),
              chevronKey: const ValueKey('tall-chevron'),
              width: double.infinity,
              triggerHeight: 48,
              value: 1,
              options: const [
                AppDropdownOption(value: 1, label: '22/23 SEASON')
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ));

      final trigger =
          tester.getRect(find.byKey(const ValueKey('tall-trigger')));
      final chevron =
          tester.getRect(find.byKey(const ValueKey('tall-chevron')));
      expect(trigger.height, 48);
      expect(chevron.height, 24);
      expect(chevron.top - trigger.top, 12);
      expect(trigger.right - chevron.right, 8);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keeps compact season options readable in a narrow trigger',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: AppDropdown<int>(
                key: const ValueKey('season-dropdown'),
                triggerKey: const ValueKey('season-trigger'),
                minWidth: 86,
                matchMenuWidth: true,
                value: null,
                selectedLabel: 'SEASON',
                options: const [
                  AppDropdownOption<int>(value: 1, label: '25/26'),
                  AppDropdownOption<int>(value: 2, label: '24/25'),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final triggerLabel = tester.renderObject<RenderParagraph>(
      find.text('SEASON'),
    );
    expect(triggerLabel.didExceedMaxLines, isFalse);

    await tester.tap(find.byKey(const ValueKey('season-dropdown')));
    await tester.pumpAndSettle();

    final optionText = find.text('25/26').last;
    final paragraph = tester.renderObject<RenderParagraph>(optionText);
    expect(paragraph.didExceedMaxLines, isFalse);
    final triggerWidth =
        tester.getSize(find.byKey(const ValueKey('season-trigger'))).width;
    final optionWidth = tester
        .getSize(find.byKey(const ValueKey('app-dropdown-option-1')))
        .width;
    expect(triggerWidth, greaterThan(86));
    expect(optionWidth, closeTo(triggerWidth, 0.1));
    expect(
      tester.getRect(find.byKey(const ValueKey('app-dropdown-option-1'))).right,
      closeTo(
        tester.getRect(find.byKey(const ValueKey('season-trigger'))).right,
        0.1,
      ),
    );
  });

  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('league icon and label stay separated at $size',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AppDropdown<int>(
              triggerKey: const ValueKey('league-trigger'),
              value: 564,
              leading: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.sports_soccer,
                    key: ValueKey('league-icon'), size: 12),
              ),
              options: const [
                AppDropdownOption(value: 564, label: 'LA LIGA'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ));

      final icon = tester.getRect(find.byKey(const ValueKey('league-icon')));
      final label = tester.getRect(find.text('LA LIGA'));
      final trigger =
          tester.getRect(find.byKey(const ValueKey('league-trigger')));
      expect(icon.size, const Size(12, 12));
      expect(label.left - icon.right, 8);
      expect(label.right, lessThan(trigger.right));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: AppDropdown<int>(
              triggerKey: const ValueKey('league-trigger'),
              value: 564,
              leading: const SizedBox.shrink(),
              options: const [
                AppDropdownOption(value: 564, label: 'LA LIGA'),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      expect(
        tester.getRect(find.text('LA LIGA')).left -
            tester.getRect(find.byKey(const ValueKey('league-trigger'))).left,
        16,
      );
    });
  }
}
