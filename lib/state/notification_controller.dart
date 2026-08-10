import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/device_notifications.dart';
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

  /// Ids already shown on the phone, so one event buzzes once.
  ///
  /// Seeded with everything present on the first load of a session and never
  /// alerted on — see [_alert]. Not persisted: it only has to outlive the
  /// session, and a fresh launch re-seeds from whatever is already in the feed,
  /// which is the same answer.
  final Set<int> _alerted = {};

  /// False until the first load of this session has been absorbed.
  bool _seeded = false;

  /// Starts polling. Safe to call repeatedly — an existing timer is replaced
  /// rather than duplicated, which would otherwise double the request rate
  /// every time the shell rebuilt.
  void start() {
    stop();
    unawaited(_begin());
    _timer = Timer.periodic(
      AppConfig.notificationPollInterval,
      (_) => unawaited(_refreshCountOnly()),
    );
  }

  /// The first load of a session, plus the permission ask.
  ///
  /// Permission is requested here rather than at launch because this is the
  /// first moment there is a reason to give: somebody has signed in and the app
  /// is about to start watching their jobs. A prompt on the login screen has no
  /// context and is the one most likely to be refused outright.
  Future<void> _begin() async {
    await refresh();
    await DeviceNotifications.requestPermission();
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
      await _alert();
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
      await _alert();
      notifyListeners();
    } on ApiException {
      // A failed background poll is not worth interrupting anyone over. The
      // next tick tries again.
    }
  }

  /// Buzzes the phone for anything unread that has not been shown yet.
  ///
  /// The first load of a session is absorbed silently. Opening the app to
  /// eleven unread notifications must not fire eleven alerts about things that
  /// already happened — the badge and the list are the right way to catch up on
  /// history, and a notification is for what just changed.
  ///
  /// Only unread rows qualify. Something read on another device, or on the
  /// dashboard, is not news here.
  Future<void> _alert() async {
    final fresh = _feed.items.where((n) => !n.isRead && !_alerted.contains(n.id));

    if (!_seeded) {
      _alerted.addAll(_feed.items.map((n) => n.id));
      _seeded = true;
      return;
    }

    // Oldest first, so the newest ends up on top of the tray.
    for (final notification in fresh.toList().reversed) {
      _alerted.add(notification.id);
      await DeviceNotifications.show(notification);
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
  ///
  /// That now includes the phone's tray and the shown-already set. Leaving
  /// either behind would hand the next person to sign in a pile of somebody
  /// else's job updates, and would make their own first load fire alerts for
  /// history they were never part of.
  void reset() {
    stop();
    _feed = NotificationFeed.empty;
    _error = null;
    _alerted.clear();
    _seeded = false;
    unawaited(DeviceNotifications.clearAll());
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
