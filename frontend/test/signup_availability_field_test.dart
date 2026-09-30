import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/SignComps/signup_availability_field.dart';
import 'package:onetouch/core/identity_name_rules.dart';

void main() {
  testWidgets('only checks the last valid input after typing pauses',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final requests = <String>[];
    await _pumpField(tester, controller, (value) async {
      requests.add(value);
      return true;
    });

    await tester.enterText(find.byType(TextFormField), 'first');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(find.byType(TextFormField), 'second');
    await tester.pump(const Duration(milliseconds: 249));
    expect(requests, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(requests, ['second']);
    expect(find.text('Available.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '.invalid');
    await tester.pump(const Duration(milliseconds: 250));
    expect(requests, ['second']);
    expect(
        tester.widget<TextField>(find.byType(TextField)).decoration?.helperText,
        isNull);
    await tester.pumpAndSettle();
    expect(find.text('Available.'), findsNothing);
  });

  testWidgets('ignores an available response for an input that has changed',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final oldResult = Completer<bool>();
    final newResult = Completer<bool>();
    var available = false;
    await _pumpField(tester, controller,
        (value) => value == 'old' ? oldResult.future : newResult.future,
        onChanged: (value) => available = value);

    await tester.enterText(find.byType(TextFormField), 'old');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.enterText(find.byType(TextFormField), 'new');
    oldResult.complete(true);
    await tester.pump();
    expect(available, isFalse);
    expect(find.text('Available.'), findsNothing);

    await tester.pump(const Duration(milliseconds: 250));
    newResult.complete(false);
    await tester.pump();
    expect(available, isFalse);
    await tester.pumpAndSettle();
    expect(
        tester
            .state<FormFieldState<String>>(find.byType(TextFormField))
            .errorText,
        'Already in use.');
    expect(find.text('Already in use.'), findsOneWidget);
  });

  testWidgets('a response after leaving the screen does not update the field',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final result = Completer<bool>();
    await _pumpField(tester, controller, (_) => result.future);
    await tester.enterText(find.byType(TextFormField), 'member');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpWidget(const SizedBox());
    result.complete(true);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpField(WidgetTester tester, TextEditingController controller,
        Future<bool> Function(String) check,
        {ValueChanged<bool>? onChanged}) =>
    tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: SignupAvailabilityField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Username'),
            validator: usernameValidationMessage,
            checkAvailability: check,
            onAvailabilityChanged: onChanged ?? (_) {},
          ),
        ),
      ),
    ));
