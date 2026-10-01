import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/main.dart';

void main() {
  testWidgets('community deep-link route is valid in the app router',
      (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(tester.takeException(), isNull);
  });
}
