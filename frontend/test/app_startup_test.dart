import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:onetouch/Onboarding.dart';
import 'package:onetouch/main.dart' as app;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('startup reaches onboarding without an API session',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});

    // 실제 로고를 미리 읽고, 테스트 시계로 애니메이션과 화면 전환을 확인해요.
    await tester.runAsync(
      () => AssetLottie('assets/animations/onetouch_logo_dark.json').load(),
    );

    app.main();
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    // API 설정이 없는 테스트에서도 첫 화면과 재시도 안내까지 렌더링해요.
    expect(find.text('Unable to load login methods. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
