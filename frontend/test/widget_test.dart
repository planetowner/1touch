import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/Splash.dart';
import 'package:onetouch/main.dart';

void main() {
  testWidgets('shows onboarding after the startup splash', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.byType(SplashScreen), findsNothing);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
