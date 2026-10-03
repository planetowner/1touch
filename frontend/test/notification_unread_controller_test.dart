import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetouch/data/notifications/notification_inbox.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';
import 'package:onetouch/data/notifications/notification_unread_controller.dart';
import 'package:onetouch/features/notifications/unread_notification_bell_icon.dart';

void main() {
  testWidgets('badge follows server unread count and clears after read',
      (tester) async {
    final repository = _UnreadRepository();
    final controller = NotificationUnreadController(repository: repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: controller,
          builder: (_, __) => UnreadNotificationBellIcon(
            color: Colors.black,
            hasUnread: controller.hasUnread,
            badgeKey: const ValueKey('test-unread-badge'),
          ),
        ),
      ),
    ));

    expect(controller.hasUnread, isFalse);
    expect(find.byKey(const ValueKey('test-unread-badge')), findsNothing);
    await controller.refresh();
    expect(controller.hasUnread, isFalse);

    repository.unreadCount = 2;
    await controller.refresh();
    await tester.pump();
    expect(controller.hasUnread, isTrue);
    expect(find.byKey(const ValueKey('test-unread-badge')), findsOneWidget);

    await repository.markReadThrough(8);
    await controller.refresh();
    await tester.pump();
    expect(controller.hasUnread, isFalse);
    expect(find.byKey(const ValueKey('test-unread-badge')), findsNothing);
  });

  test('a previous account response cannot restore its unread badge', () async {
    final repository = _UnreadRepository();
    final pending = Completer<NotificationInboxPageData>();
    repository.nextPage = pending.future;
    final controller = NotificationUnreadController(repository: repository);
    addTearDown(controller.dispose);

    final refresh = controller.refresh();
    controller.clear();
    pending.complete(_page(1));
    await refresh;
    expect(controller.hasUnread, isFalse);
  });
}

NotificationInboxPageData _page(int unreadCount) => NotificationInboxPageData(
      items: const [],
      unreadCount: unreadCount,
      nextBeforeId: null,
    );

class _UnreadRepository implements NotificationInboxRepository {
  int unreadCount = 0;
  Future<NotificationInboxPageData>? nextPage;

  @override
  Future<NotificationInboxPageData> load({
    int? beforeId,
    int limit = 30,
    int? teamId,
  }) async =>
      await (nextPage ?? Future.value(_page(unreadCount)));

  @override
  Future<void> markReadThrough(int notificationId) async {
    unreadCount = 0;
  }
}
