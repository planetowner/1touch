import 'package:flutter/foundation.dart';
import 'package:onetouch/data/notifications/notification_inbox_repository.dart';

class NotificationUnreadController extends ChangeNotifier {
  NotificationUnreadController(
      {required NotificationInboxRepository repository})
      : _repository = repository;

  final NotificationInboxRepository _repository;
  int _request = 0;
  bool _hasUnread = false;

  bool get hasUnread => _hasUnread;

  Future<void> refresh() async {
    final request = ++_request;
    try {
      final page = await _repository.load(limit: 1);
      if (request != _request) return;
      final hasUnread = page.unreadCount > 0;
      if (_hasUnread == hasUnread) return;
      _hasUnread = hasUnread;
      notifyListeners();
    } on Object {
      // Keep the last confirmed state until the inbox can be checked again.
    }
  }

  void clear() {
    _request++;
    if (!_hasUnread) return;
    _hasUnread = false;
    notifyListeners();
  }
}
