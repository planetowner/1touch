import 'dart:async';

import 'package:flutter/material.dart';
import 'package:onetouch/features/loading/football_loading_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:onetouch/core/style.dart';
import 'package:onetouch/core/stylesheet_dark.dart';
import 'package:onetouch/data/notifications/notification_inbox.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository_provider.dart';
import 'package:onetouch/data/notifications/notification_unread_controller.dart';
import 'package:onetouch/data/notifications/notification_unread_controller_provider.dart';
import 'package:onetouch/features/community/community_identity.dart';
import 'package:onetouch/l10n/app_localizations.dart';
import 'package:onetouch/l10n/date_labels.dart';

class NotificationInboxPage extends StatefulWidget {
  const NotificationInboxPage(
      {super.key, this.repository, this.unreadController});

  final NotificationInboxRepository? repository;
  final NotificationUnreadController? unreadController;

  @override
  State<NotificationInboxPage> createState() => _NotificationInboxPageState();
}

class _NotificationInboxPageState extends State<NotificationInboxPage> {
  final ScrollController _scrollController = ScrollController();
  List<CommunityNotification> _items = const [];
  int? _nextBeforeId;
  Object? _error;
  bool _loading = true;
  bool _loadingMore = false;

  NotificationInboxRepository get _repository =>
      widget.repository ?? notificationInboxRepository;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_loadInitial());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.extentAfter < 240) {
      unawaited(_loadMore());
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _repository.load();
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _nextBeforeId = page.nextBeforeId;
        _loading = false;
      });
      if (page.items.isNotEmpty && page.unreadCount > 0) {
        unawaited(_markRead(page.items.first.notificationId));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final beforeId = _nextBeforeId;
    if (_loading || _loadingMore || beforeId == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repository.load(beforeId: beforeId);
      if (!mounted) return;
      final knownIds = _items.map((item) => item.notificationId).toSet();
      setState(() {
        _items = List.unmodifiable([
          ..._items,
          ...page.items.where((item) => knownIds.add(item.notificationId)),
        ]);
        _nextBeforeId = page.nextBeforeId;
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
    }
  }

  Future<void> _markRead(int notificationId) async {
    try {
      await _repository.markReadThrough(notificationId);
      if (widget.repository == null || widget.unreadController != null) {
        await (widget.unreadController ?? notificationUnreadController)
            .refresh();
      }
    } on Object catch (error) {
      debugPrint('Unable to mark notifications as read: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      key: const ValueKey('notification-inbox-scaffold'),
      backgroundColor: mainPageBackground(context),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(24, appBarContentTop(context), 24, 0),
            child: SizedBox(
              height: 32,
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      icon: Icon(Icons.arrow_back_ios_new, color: foreground),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      tr(context, 'Notifications'),
                      textAlign: TextAlign.center,
                      style: Body1.style.copyWith(color: foreground),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 32,
                      onPressed: () => context.push('/search'),
                      icon: Icon(Icons.search, color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) {
      return const Center(child: FootballLoadingIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _InboxMessage(
        message: tr(context, 'Unable to load notifications.'),
        actionLabel: tr(context, 'Try again'),
        onAction: _loadInitial,
      );
    }
    if (_items.isEmpty) {
      return _InboxMessage(message: tr(context, 'No notifications yet.'));
    }
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.separated(
        key: const ValueKey('notification-inbox-list'),
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: _items.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: FootballLoadingIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: _NotificationTile(notification: _items[index]),
          );
        },
        separatorBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Divider(
            color: AppColors.of(context).divider,
            height: 1,
            thickness: 1,
          ),
        ),
      ),
    );
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: Body1.style, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});

  final CommunityNotification notification;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(notification.destination),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 74),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _NotificationAvatar(kind: notification.kind),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(
                      context,
                      notification.kind ==
                              CommunityNotificationKind.postReaction
                          ? 'Reaction'
                          : 'Comment',
                    ),
                    style: Body1_b.style.copyWith(color: foreground),
                  ),
                  _NotificationBody(notification: notification),
                  const SizedBox(height: 8),
                  Text(
                    relativeTimeLabel(
                      notification.createdAt,
                      locale: Localizations.localeOf(context),
                    ),
                    style: Body2.style.copyWith(
                      color: AppColors.of(context).mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationAvatar extends StatelessWidget {
  const _NotificationAvatar({required this.kind});

  final CommunityNotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: 74,
      height: 74,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            width: 64,
            height: 64,
            child: Image.asset('assets/profileAvatar.png'),
          ),
          Positioned(
            top: 34,
            left: 34,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? AppPalette.lightGrey : AppPalette.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                kind == CommunityNotificationKind.postReaction
                    ? Icons.thumb_up_outlined
                    : Icons.chat_bubble_outline,
                color: isDark ? AppPalette.white : AppPalette.black,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationBody extends StatelessWidget {
  const _NotificationBody({required this.notification});

  final CommunityNotification notification;

  @override
  Widget build(BuildContext context) {
    final foreground = Theme.of(context).colorScheme.onSurface;
    final author = communityAuthorLabel(
      username: notification.username,
      displayName: notification.displayName,
      authorDeleted: false,
      locale: Localizations.localeOf(context),
    );
    if (notification.kind == CommunityNotificationKind.postReaction) {
      return Text(
        tr(
          context,
          '{user} liked your post.',
          {'user': author},
        ),
        style: Body1.style.copyWith(color: foreground),
      );
    }
    return RichText(
      text: TextSpan(
        style: Body1.style.copyWith(color: foreground),
        children: [
          TextSpan(
            text: tr(
              context,
              '{user} commented on your post: ',
              {'user': author},
            ),
          ),
          TextSpan(
            text: notification.commentPreview,
            style: Body1_b.style.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
