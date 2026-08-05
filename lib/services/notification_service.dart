import '../core/api_client.dart';
import '../models/app_notification.dart';

/// The in-app notification feed.
///
/// Pull, not push: this is polled while the app is open. Nothing arrives while
/// it is closed, which is the deliberate trade for needing no Firebase project,
/// no device tokens and no credentials to run.
class NotificationApi {
  NotificationApi(this._api);

  final ApiClient _api;

  Future<NotificationFeed> feed({bool unreadOnly = false}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: {'unreadOnly': unreadOnly},
    );

    return NotificationFeed.fromJson(data);
  }

  /// Just the badge number — cheap enough to poll on a timer.
  Future<int> unreadCount() => _api.get<int>('/notifications/unread-count');

  Future<void> markRead(int id) =>
      _api.put<dynamic>('/notifications/$id/read');

  Future<int> markAllRead() => _api.put<int>('/notifications/read-all');

  Future<void> remove(int id) => _api.delete<dynamic>('/notifications/$id');

  /// Whether this account wants its phone to buzz.
  ///
  /// Kept on the server rather than in the phone's own preferences, because the
  /// decision has to be honoured when a notification is *sent*. A purely local
  /// switch still lets the server push to a device that has asked to be left
  /// alone, and stops keeping its promise the moment the app is reinstalled.
  Future<bool> notificationsEnabled() async {
    final data = await _api.get<Map<String, dynamic>>(
      '/notifications/preferences',
    );

    return data['enabled'] as bool? ?? true;
  }

  /// Turns delivery on or off. The in-app feed keeps filling either way — this
  /// silences the phone, it does not erase the history.
  Future<bool> setNotificationsEnabled(bool enabled) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/notifications/preferences',
      body: {'enabled': enabled},
    );

    return data['enabled'] as bool? ?? enabled;
  }
}
