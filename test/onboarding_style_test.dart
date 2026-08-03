import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/core/style.dart' as app_style;

void main() {
  for (final testCase in <({
    ThemeData theme,
    Color socialBackground,
    Color emailBackground,
    Color emailForeground,
  })>[
    (
      theme: app_style.darktheme,
      socialBackground: app_style.AppPalette.lightGrey,
      emailBackground: app_style.AppPalette.darkGrey,
      emailForeground: app_style.AppPalette.white,
    ),
    (
      theme: app_style.whitetheme,
      socialBackground: app_style.AppPalette.black,
      emailBackground: app_style.AppPalette.lightGreyBox,
      emailForeground: app_style.AppPalette.black,
    ),
  ]) {
    testWidgets('email action and divider use onboarding palette',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 852));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: testCase.theme,
          home: const OnboardingScreen(),
        ),
      );
      await tester.pump();

      final emailLabel = find.text('Continue with email');
      final emailButton = find.ancestor(
        of: emailLabel,
        matching: find.byType(ElevatedButton),
      );
      final button = tester.widget<ElevatedButton>(emailButton);

      expect(find.byIcon(Icons.mail_outline), findsNothing);
      expect(
        button.style?.backgroundColor?.resolve({}),
        testCase.emailBackground,
      );
      expect(
        button.style?.foregroundColor?.resolve({}),
        testCase.emailForeground,
      );
      expect(
        tester.getCenter(emailLabel).dx,
        closeTo(tester.getCenter(emailButton).dx, 0.1),
      );
      expect(
        tester.widget<Divider>(find.byType(Divider)).color,
        app_style.AppPalette.lightGrey,
      );

      for (final label in [
        'Continue with Google',
        'Continue with Apple',
        'Continue with Facebook',
      ]) {
        final socialButtonFinder = find.ancestor(
          of: find.text(label),
          matching: find.byType(ElevatedButton),
        );
        final socialButton = tester.widget<ElevatedButton>(socialButtonFinder);
        expect(
          socialButton.style?.backgroundColor?.resolve({}),
          testCase.socialBackground,
        );
        expect(
          socialButton.style?.foregroundColor?.resolve({}),
          app_style.AppPalette.white,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
