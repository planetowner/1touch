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

  testWidgets('shows the full Korean Champions League option', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: whitetheme,
        home: Scaffold(
          body: AppDropdown<int>(
            key: const ValueKey('league-dropdown'),
            width: 164.5,
            value: 1,
            options: const [
              AppDropdownOption<int>(
                value: 1,
                label: 'UEFA 챔피언스리그',
              ),
              AppDropdownOption<int>(value: 2, label: '라리가'),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('league-dropdown')));
    await tester.pumpAndSettle();

    final koreanOption = tester.renderObject<RenderParagraph>(
      find.text('UEFA 챔피언스리그').last,
    );
    expect(koreanOption.didExceedMaxLines, isFalse);
  });
}
