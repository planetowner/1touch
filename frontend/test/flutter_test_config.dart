import 'dart:async';
import 'package:intl/date_symbol_data_local.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // 실제 앱의 GlobalMaterialLocalizations처럼 테스트에서도 날짜 번역을 준비해요.
  await initializeDateFormatting();
  await testMain();
}
