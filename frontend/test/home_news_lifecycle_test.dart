import 'support/app_catalog.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/user_preferences.dart';
import 'package:onetouch/data/home/home_repository.dart';
import 'package:onetouch/data/home/news_repository.dart';
import 'package:onetouch/models/home_content_item.dart';
import 'package:onetouch/models/home_data.dart';
import 'package:onetouch/models/team.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/screens/HomeScreen.dart';
import 'package:onetouch/features/home/screen/home_screen_features.dart';

void main() {
  setUpAppCatalog();
  for (final imageFails in [false, true]) {
    testWidgets(
        'loads news and prefetches offscreen images before Home completes, imageFails=$imageFails',
        (tester) async {
      final homeReady = Completer<void>();
      final home = _HomeRepository(ready: homeReady.future);
      final content = _ContentRepository();
      const provider = NetworkImage('https://example.com/early-news.jpg');
      final imageReady = Completer<ImageInfo>();
      final imageStream = _RecordingImageStream(imageReady.future);
      final cache = PaintingBinding.instance.imageCache;
      cache.putIfAbsent(provider, () => imageStream);
      addTearDown(() => cache.evict(provider));
      final initialListeners = imageStream.listenerCount;

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: appSupportedLocales,
        localizationsDelegates: appLocalizationDelegates,
        theme: app_style.whitetheme,
        home: HomeScreen(repository: home, newsRepository: content),
      ));
      expect(homeReady.isCompleted, isFalse);
      expect(content.calls.single.language, 'ko');
      content.calls.single.completer
          .complete(_news('미리 받은 기사', imageUrl: provider.url));
      await tester.pump();
      expect(find.byType(MyNews), findsNothing);
      expect(imageStream.listenerCount, greaterThan(initialListeners));

      homeReady.complete();
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(MyNews), 500,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('미리 받은 기사'), findsOneWidget);
      expect(imageReady.isCompleted, isFalse);
      expect(content.calls, hasLength(1));

      if (imageFails) {
        imageReady.completeError(StateError('image offline'));
      } else {
        final image = await tester.runAsync(() => createTestImage());
        imageReady.complete(ImageInfo(image: image!));
      }
      await tester.pump();
      expect(find.text('미리 받은 기사'), findsOneWidget);
      if (imageFails) {
        expect(find.byIcon(Icons.article_outlined), findsOneWidget);
      } else {
        expect(cache.statusForKey(provider).keepAlive, isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('changing team removes old news and rejects its late response',
      (tester) async {
    final oldViewedTeam = currentUserPreferences.viewedTeamId.value;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      currentUserPreferences.viewTeam(oldViewedTeam);
    });
    final home = _HomeRepository();
    final content = _ContentRepository();
    await tester.pumpWidget(MaterialApp(
        theme: app_style.whitetheme,
        home: HomeScreen(repository: home, newsRepository: content)));
    await tester.pump();
    expect(content.calls.single.teamId, 83);
    home.teamId = 3468;
    currentUserPreferences.viewTeam(3468);
    await tester.pump();
    await tester.pump();
    expect(content.calls.last.teamId, 3468);
    content.calls.last.completer.complete(_news('새 팀 기사'));
    await tester.pump();
    content.calls.first.completer.complete(_news('이전 팀 기사'));
    await tester.pump();
    await tester.scrollUntilVisible(find.byType(MyNews), 500,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('새 팀 기사'), findsOneWidget);
    expect(find.text('이전 팀 기사'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final refreshFails in [false, true]) {
    testWidgets(
        'tab refresh keeps existing news mounted, refreshFails=$refreshFails',
        (tester) async {
      final home = _HomeRepository();
      final content = _ContentRepository();
      final active = ValueNotifier(true);
      addTearDown(active.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: app_style.whitetheme,
          home: ValueListenableBuilder<bool>(
            valueListenable: active,
            child: HomeScreen(repository: home, newsRepository: content),
            builder: (context, enabled, child) =>
                TickerMode(enabled: enabled, child: child!),
          )));
      await tester.pump();
      content.calls.single.completer.complete(_news('첫 기사'));
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(MyNews), 500,
          scrollable: find.byType(Scrollable).first);
      final firstArticle = tester.element(find.text('첫 기사'));
      await tester.pump(const Duration(minutes: 31));
      expect(content.calls, hasLength(1));
      active.value = false;
      await tester.pump();
      active.value = true;
      await tester.pump();
      await tester.pump();
      expect(content.calls, hasLength(2));
      expect(tester.element(find.text('첫 기사')), same(firstArticle));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      if (refreshFails) {
        content.calls.last.completer.completeError(StateError('offline'));
      } else {
        content.calls.last.completer.complete(_news('새 기사'));
      }
      await tester.pumpAndSettle();
      expect(tester.widget<MyNews>(find.byType(MyNews)).isLoading, isFalse);
      expect(find.text(refreshFails ? '첫 기사' : '새 기사'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Unable to load news.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final changeTeam in [false, true]) {
    testWidgets('changing the feed clears loaded news, changeTeam=$changeTeam',
        (tester) async {
      final locale = ValueNotifier(const Locale('en'));
      addTearDown(locale.dispose);
      final content = _ContentRepository();
      await tester.pumpWidget(ValueListenableBuilder<Locale>(
        valueListenable: locale,
        child: HomeScreen(
          repository: _HomeRepository(),
          newsRepository: content,
        ),
        builder: (context, value, child) => MaterialApp(
          locale: value,
          supportedLocales: appSupportedLocales,
          localizationsDelegates: appLocalizationDelegates,
          theme: app_style.whitetheme,
          home: child,
        ),
      ));
      content.calls.single.completer.complete(_news('이전 기사'));
      await tester.pump();
      await tester.scrollUntilVisible(find.byType(MyNews), 500,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('이전 기사'), findsOneWidget);

      if (changeTeam) {
        currentUserPreferences.viewTeam(3468);
      } else {
        locale.value = const Locale('ko');
      }
      await tester.pump();
      await tester.pump();
      expect(content.calls, hasLength(2));
      expect(content.calls.last.teamId, changeTeam ? 3468 : 83);
      expect(content.calls.last.language, changeTeam ? 'en' : 'ko');
      await tester.scrollUntilVisible(find.byType(MyNews), 500,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('이전 기사'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      content.calls.last.completer.complete(_news('새 기사'));
      await tester.pump();
      expect(find.text('새 기사'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

List<HomeContentItem> _news(String title, {String? imageUrl}) => [
      HomeContentItem(
          title: title,
          source: '공급자',
          publishedAt: DateTime.now(),
          imageUrl: imageUrl),
    ];

class _HomeRepository implements HomeRepository {
  _HomeRepository({this.ready});

  final Future<void>? ready;
  int teamId = 83;
  @override
  Future<HomeData> load({int? teamId, DateTime? start, DateTime? end}) async {
    if (ready != null) await ready;
    return HomeData(
      favoriteTeam: Team(teamId: teamId ?? this.teamId, name: '선택한 팀'),
      followingTeams: const [
        Team(teamId: 83, name: '바르셀로나'),
        Team(teamId: 3468, name: '레알 마드리드')
      ],
      nextMatch: null,
      lastMatch: null,
      calendar: const [],
      highlights: const [],
    );
  }
}

class _ContentRepository implements NewsRepository {
  final calls = <({
    int teamId,
    String language,
    Completer<List<HomeContentItem>> completer
  })>[];

  @override
  Future<List<HomeContentItem>> loadForTeam(
    int favoriteTeamId, {
    required String language,
  }) {
    final call = (
      teamId: favoriteTeamId,
      language: language,
      completer: Completer<List<HomeContentItem>>()
    );
    calls.add(call);
    return call.completer.future;
  }
}

class _RecordingImageStream extends OneFrameImageStreamCompleter {
  _RecordingImageStream(super.image);

  int listenerCount = 0;

  @override
  void addListener(ImageStreamListener listener) {
    listenerCount++;
    super.addListener(listener);
  }
}
