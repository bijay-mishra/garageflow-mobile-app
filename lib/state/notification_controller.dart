import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/config.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

/// The notification feed and its unread badge.
///
/// Polls while the app is in the foreground. There is no push channel, so this
/// timer *is* the delivery mechanism — see [NotificationApi].
class NotificationController extends ChangeNotifier {
  NotificationController(this._api);

  final NotificationApi _api;

  Timer? _timer;
  bool _loading = false;
  String? _error;
  NotificationFeed _feed = NotificationFeed.empty;

  List<AppNotification> get items => _feed.items;
  int get unreadCount => _feed.unreadCount;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasUnread => _feed.unreadCount > 0;

  /// Starts polling. Safe to call repeatedly — an existing timer is replaced
  /// rather than duplicated, which would otherwise double the request rate
  /// every time the shell rebuilt.
  void start() {
    stop();
    unawaited(refresh());
    _timer = Timer.periodic(
      AppConfig.notificationPollInterval,
      (_) => unawaited(_refreshCountOnly()),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _feed = await _api.feed();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The polled path: fetches the count, and only pulls the whole feed when
  /// that number has actually moved. Most polls cost one small integer.
  Future<void> _refreshCountOnly() async {
    try {
      final count = await _api.unreadCount();
      if (count == _feed.unreadCount) return;

      _feed = await _api.feed();
      notifyListeners();
    } on ApiException {
      // A failed background poll is not worth interrupting anyone over. The
      // next tick tries again.
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    // Optimistic: the row greys out on tap. A failure is corrected by the next
    // poll, and the cost of being briefly wrong about a read flag is nil.
    _replace(notification.copyWith(isRead: true), unreadDelta: -1);

    try {
      await _api.markRead(notification.id);
    } on ApiException {
      _replace(notification.copyWith(isRead: false), unreadDelta: 1);
    }
  }

  Future<void> markAllRead() async {
    if (!hasUnread) return;

    final previous = _feed;
    _feed = NotificationFeed(
      unreadCount: 0,
      items: _feed.items.map((n) => n.copyWith(isRead: true)).toList(),
    );
    notifyListeners();

    try {
      await _api.markAllRead();
    } on ApiException catch (error) {
      _feed = previous;
      _error = error.message;
      notifyListeners();
    }
  }

  Future<void> remove(AppNotification notification) async {
    final previous = _feed;

    _feed = NotificationFeed(
      unreadCount: _feed.unreadCount - (notification.isRead ? 0 : 1),
      items: _feed.items.where((n) => n.id != notification.id).toList(),
    );
    notifyListeners();

    try {
      await _api.remove(notification.id);
    } on ApiException {
      _feed = previous;
      notifyListeners();
    }
  }

  /// Clears everything on sign-out, so the next account never sees a flash of
  /// the previous one's notifications.
  void reset() {
    stop();
    _feed = NotificationFeed.empty;
    _error = null;
    notifyListeners();
  }

  void _replace(AppNotification updated, {required int unreadDelta}) {
    _feed = NotificationFeed(
      unreadCount: (_feed.unreadCount + unreadDelta).clamp(0, 1 << 30),
      items: [
        for (final item in _feed.items)
          if (item.id == updated.id) updated else item,
      ],
    );
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
