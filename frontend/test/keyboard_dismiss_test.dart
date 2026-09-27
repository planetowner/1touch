import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/keyboard_dismiss.dart';

void main() {
  testWidgets('dismisses the keyboard on interactions outside the input',
      (tester) async {
    final firstFocus = FocusNode();
    final secondFocus = FocusNode();
    addTearDown(firstFocus.dispose);
    addTearDown(secondFocus.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AppKeyboardDismissBoundary(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('first-input'),
                  focusNode: firstFocus,
                ),
                TextField(
                  key: const ValueKey('second-input'),
                  focusNode: secondFocus,
                ),
                ElevatedButton(
                  key: const ValueKey('other-interaction'),
                  onPressed: () {},
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('first-input')));
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    // Interacting with the same input keeps its focus and keyboard.
    await tester.tap(find.byKey(const ValueKey('first-input')));
    await tester.pump();
    expect(firstFocus.hasFocus, isTrue);

    // Moving to another input transfers focus without dismissing it.
    await tester.tap(find.byKey(const ValueKey('second-input')));
    await tester.pump();
    expect(firstFocus.hasFocus, isFalse);
    expect(secondFocus.hasFocus, isTrue);

    // Any non-input interaction dismisses the active keyboard.
    await tester.tap(find.byKey(const ValueKey('other-interaction')));
    await tester.pump();
    expect(secondFocus.hasFocus, isFalse);
    expect(tester.takeException(), isNull);
  });
}
