import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/locale_controller.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/features/media/native_avatar_header.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('$platform follows native title and close icon measurements',
        (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final previousLocale = appLocaleController.value;
      appLocaleController.value = const Locale('ko');
      String? channel;
      final measuredLefts = <double>[];
      messenger.setMockMethodCallHandler(SystemChannels.platform_views,
          (call) async {
        if (call.method == 'create') {
          final id = (call.arguments as Map)['id'];
          channel = 'onetouch/avatar_header/$id';
          messenger.setMockMethodCallHandler(
              MethodChannel(channel!), (_) async => null);
          return platform == TargetPlatform.android ? 0 : null;
        }
        if (call.method == 'resize') {
          final args = call.arguments as Map;
          return {'width': args['width'], 'height': args['height']};
        }
        return null;
      });
      addTearDown(() {
        appLocaleController.value = previousLocale;
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (channel != null) {
          messenger.setMockMethodCallHandler(MethodChannel(channel!), null);
        }
      });

      Future<void> layout(
          double height, double centerY, double closeIconLeft) async {
        await messenger.handlePlatformMessage(
            channel!,
            const StandardMethodCodec().encodeMethodCall(MethodCall('layout', {
              'height': height,
              'titleCenterY': centerY,
              if (platform == TargetPlatform.android)
                'closeIconLeft': closeIconLeft,
            })),
            (_) {});
        await tester.pump();
      }

      await tester.pumpWidget(MaterialApp(
        theme: whitetheme.copyWith(platform: platform),
        home: Scaffold(
          body: NativeAvatarHeader(
              onCancel: () {},
              onDone: () {},
              saving: false,
              onCloseIconLeftMeasured: measuredLefts.add),
        ),
      ));
      await tester.pumpAndSettle();
      expect(channel, isNotNull);
      final title = find.byType(Text);
      expect(tester.widget<Text>(title).style, Heading5.style);

      // 바 높이의 절반과 버튼 행의 중심이 달라도 네이티브 배치가 기준이에요.
      await layout(64, 24, 18.333);
      expect(tester.getRect(find.byType(NativeAvatarHeader)).height, 64);
      expect(tester.getCenter(title).dy, 24);
      await layout(56, 28, 26.5);
      expect(tester.getCenter(title).dy, 28);
      // 제목 위치가 그대로여도 X의 새 좌표는 부모 화면에 전달해요.
      await layout(56, 28, 20.25);
      expect(measuredLefts,
          platform == TargetPlatform.android ? [18.333, 26.5, 20.25] : isEmpty);
      expect(tester.widget<Text>(title).style, Heading5.style);
      expect(tester.takeException(), isNull);
    });
  }
}
