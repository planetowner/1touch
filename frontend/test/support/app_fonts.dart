import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> loadAppFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 테스트 기본 폰트 대신 앱 폰트로 글자 너비와 행간을 검증해요.
  for (final font in [
    ('Archivo', 'assets/fonts/Archivo-Variable.ttf'),
    ('Pretendard', 'assets/fonts/Pretendard-Regular.otf'),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
  }
}
