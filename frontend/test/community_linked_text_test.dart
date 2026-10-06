import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/features/community/community_linked_text.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('post links open without opening the card at $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final launches = <MethodCall>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        launches.add(call);
        return true;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null));

      const body =
          'Read https://example.com/path?x=1, then www.example.org/docs.';
      var cardTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: size.width - 48,
                child: GestureDetector(
                  onTap: () => cardTaps++,
                  child: const CommunityLinkedText(
                    text: body,
                    style: TextStyle(fontSize: 15),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.descendant(
          of: find.byType(CommunityLinkedText),
          matching: find.byType(Text),
        ),
      );
      final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
      expect(
          spans
              .where((span) => span.recognizer != null)
              .map((span) => span.text),
          ['https://example.com/path?x=1', 'www.example.org/docs']);
      expect(spans.last.text, '.');

      Future<void> tapText(int start, int end) async {
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(CommunityLinkedText),
            matching: find.byType(RichText),
          ),
        );
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: start, extentOffset: end),
            )
            .first;
        await tester.tapAt(paragraph.localToGlobal(box.toRect().center));
        await tester.pump();
      }

      await tapText(body.indexOf('https://'), body.indexOf('https://') + 5);
      expect(launches.last.arguments['url'], 'https://example.com/path?x=1');
      expect(launches.last.arguments['useWebView'], false);
      expect(cardTaps, 0);

      await tapText(body.indexOf('www.'), body.indexOf('www.') + 4);
      expect(launches.last.arguments['url'], 'https://www.example.org/docs');
      expect(cardTaps, 0);

      await tapText(0, 4);
      expect(cardTaps, 1);
      expect(launches, hasLength(2));
      expect(tester.takeException(), isNull);
    });
  }
}
