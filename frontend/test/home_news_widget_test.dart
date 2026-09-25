import 'package:onetouch/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/features/home/screen/home_screen_features.dart';
import 'package:onetouch/models/home_content_item.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'news supports $size dark=$dark without padding missing articles',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          locale: const Locale('ko'),
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: dark ? app_style.darktheme : app_style.whitetheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: MyNews(news: [
            for (var i = 0; i < 3; i++)
              HomeContentItem(
                  title: '선택한 팀의 긴 뉴스 제목이 두 줄을 넘어가면 말줄임표로 표시돼요 $i',
                  source: '포포투',
                  publishedAt: DateTime.now(),
                  destinationUrl: 'https://example.com/$i'),
          ]))),
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.article_outlined), findsNWidgets(3));
        expect(find.text('포포투 · 방금 전'), findsNWidgets(3));
        expect(find.textContaining('포포투'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const MaterialApp(
            locale: const Locale('ko'),
            supportedLocales: appSupportedLocales,
            localizationsDelegates: appLocalizationDelegates,
            home: Scaffold(body: MyNews(news: []))));
        await tester.pumpAndSettle();
        expect(find.text('아직 팀 뉴스가 없어요.'), findsOneWidget);
        expect(find.byType(GestureDetector), findsNothing);
      });
    }
  }

  testWidgets('image failure keeps article title and destination enabled',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
            body: MyNews(news: [
          HomeContentItem(
              title: '실제 기사',
              source: '실제 매체',
              publishedAt: DateTime.now(),
              imageUrl: 'https://example.com/broken.jpg',
              destinationUrl: 'https://example.com/story'),
        ]))));
    await tester.pumpAndSettle();
    expect(find.text('실제 기사'), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(tester.widget<GestureDetector>(find.byType(GestureDetector)).onTap,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('news and highlights share relative dates in the current locale',
      (tester) async {
    final now = DateTime.now();
    final items = [
      for (final days in [0, 1, 35])
        HomeContentItem(
          title: 'Content $days',
          source: 'Channel or publisher',
          publishedAt:
              days == 0 ? now : DateTime(now.year, now.month, now.day - days),
        ),
    ];
    final labels = {
      'en': ['Just now', 'Yesterday', '5 weeks ago'],
      'ko': ['방금 전', '어제', '5주 전'],
      'ja': ['たった今', '昨日', '5週間前'],
      'zh': ['刚刚', '昨天', '5周前'],
    };
    for (final locale in appSupportedLocales) {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              MyHighlights(highlights: items, fallbacks: const []),
              MyNews(news: items),
            ]),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      for (final label in labels[locale.languageCode]!) {
        expect(find.text('Channel or publisher · $label'), findsNWidgets(2));
      }
      expect(find.textContaining('Channel or publisher'), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('failure and loading are distinct from an empty feed',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(
            body: MyNews(
          news: const [],
          hasError: true,
          onRetry: () => retried = true,
        ))));
    await tester.pumpAndSettle();
    expect(find.text('아직 팀 뉴스가 없어요.'), findsNothing);
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
    await tester.pumpWidget(const MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        home: Scaffold(body: MyNews(news: [], isLoading: true))));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No team news yet.'), findsNothing);
  });
}
