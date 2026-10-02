import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/comm_pages/notification_inbox.dart';
import 'package:onetouch/core/style.dart' as app_style;
import 'package:onetouch/core/stylesheet.dart';
import 'package:onetouch/data/notifications/notification_inbox.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';

void main() {
  Future<void> pumpInbox(
    WidgetTester tester, {
    required ThemeData theme,
    required Size size,
    NotificationInboxRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: NotificationInboxPage(
          repository: repository ?? _StaticNotificationInboxRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('notification inbox follows the compact light design',
      (tester) async {
    final repository = _StaticNotificationInboxRepository();
    await pumpInbox(
      tester,
      theme: app_style.whitetheme,
      size: const Size(320, 568),
      repository: repository,
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('notification-inbox-scaffold')),
    );
    final backIcon = tester.widget<Icon>(find.byIcon(Icons.arrow_back_ios_new));
    final searchIcon = tester.widget<Icon>(find.byIcon(Icons.search));
    final title = tester.widget<Text>(find.text('Notifications'));

    expect(scaffold.backgroundColor, app_style.AppPalette.lightModeDarkGrey);
    expect(backIcon.color, app_style.AppPalette.black);
    expect(searchIcon.color, app_style.AppPalette.black);
    expect(
        title.style, Body1.style.copyWith(color: app_style.AppPalette.black));
    expect(
        find.byKey(const ValueKey('notification-inbox-list')), findsOneWidget);
    expect(find.text('Reaction'), findsOneWidget);
    expect(find.text('Comment'), findsOneWidget);
    expect(find.text('TEAM'), findsNothing);
    expect(repository.markedThroughId, 8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification inbox retains its tall dark design',
      (tester) async {
    await pumpInbox(
      tester,
      theme: app_style.darktheme,
      size: const Size(430, 932),
    );

    final scaffold = tester.widget<Scaffold>(
      find.byKey(const ValueKey('notification-inbox-scaffold')),
    );
    expect(scaffold.backgroundColor, app_style.AppPalette.black);
    expect(find.text('Reaction'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notification rows open their API destination routes',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/notifications',
      routes: [
        GoRoute(
          path: '/notifications',
          builder: (_, __) => NotificationInboxPage(
            repository: _StaticNotificationInboxRepository(),
          ),
        ),
        GoRoute(
          path: '/notifications/post/:postId',
          builder: (_, state) => Scaffold(
            body: Text('post ${state.pathParameters['postId']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(
      theme: app_style.darktheme,
      routerConfig: router,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reaction'));
    await tester.pumpAndSettle();

    expect(find.text('post 12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StaticNotificationInboxRepository
    implements NotificationInboxRepository {
  int? markedThroughId;

  @override
  Future<NotificationInboxPageData> load({
    int? beforeId,
    int limit = 30,
    int? teamId,
  }) async =>
      NotificationInboxPageData(
        items: [
          CommunityNotification(
            notificationId: 8,
            kind: CommunityNotificationKind.postReaction,
            postId: 12,
            actorId: 3,
            teamId: 83,
            username: null,
            displayName: 'User One',
            commentPreview: '',
            createdAt:
                DateTime.now().toUtc().subtract(const Duration(hours: 2)),
            readAt: null,
            destination: '/notifications/post/12',
          ),
          CommunityNotification(
            notificationId: 7,
            kind: CommunityNotificationKind.postComment,
            postId: 12,
            commentId: 40,
            actorId: 4,
            teamId: 83,
            username: 'User Two',
            displayName: 'User Two',
            commentPreview: 'Good point',
            createdAt:
                DateTime.now().toUtc().subtract(const Duration(hours: 3)),
            readAt: null,
            destination: '/notifications/post/12',
          ),
        ],
        unreadCount: 2,
        nextBeforeId: null,
      );

  @override
  Future<void> markReadThrough(int notificationId) async {
    markedThroughId = notificationId;
  }
}
