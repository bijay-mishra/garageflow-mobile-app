import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/config.dart';
import '../services/support_service.dart';

/// The unread count on the chat icon.
///
/// Its own controller rather than a field on NotificationController, because
/// the two count different things and a customer can easily have one and not
/// the other: a bell full of job updates and no reply waiting, or a reply from
/// the office and a quiet bell. Merging them would make one badge that is wrong
/// about both.
///
/// Polled on the same interval as the notification feed. There is no push for
/// this — a support reply already sends a notification, and that is what wakes
/// a closed app; this is only for the badge while somebody is looking.
class SupportController extends ChangeNotifier {
  SupportController(this._api);

  final SupportService _api;

  Timer? _timer;
  int _unread = 0;

  int get unread => _unread;

  /// Starts polling. Safe to call repeatedly — an existing timer is replaced
  /// rather than duplicated, which would otherwise double the request rate
  /// every time the shell rebuilt.
  void start() {
    stop();
    unawaited(refresh());
    _timer = Timer.periodic(
      AppConfig.notificationPollInterval,
      (_) => unawaited(refresh()),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    try {
      final count = await _api.unread();

      if (count == _unread) return;

      _unread = count;
      notifyListeners();
    } on ApiException {
      // Left at whatever it was. A badge is not worth an error state, and a
      // stale number is a smaller lie than a zero that says "nothing waiting"
      // when the request simply failed.
    }
  }

  /// Called after opening a conversation, so the badge clears without waiting
  /// for the next poll to come round.
  void markSeen() => unawaited(refresh());

  /// Clears on sign-out, so the next person to use this phone does not inherit
  /// a count of somebody else's conversations.
  void reset() {
    stop();
    _unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
