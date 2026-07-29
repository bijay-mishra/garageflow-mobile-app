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
}
