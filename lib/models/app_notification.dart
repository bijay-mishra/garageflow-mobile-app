/// One entry in the in-app feed.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.kind,
    required this.entityId,
    required this.createdAt,
    required this.isRead,
  });

  final int id;
  final String title;
  final String body;

  /// job, booking, invoice or system — drives the icon.
  final String kind;

  /// Id of the job, booking or invoice this is about, for deep links.
  final String? entityId;

  final DateTime createdAt;
  final bool isRead;

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    kind: kind,
    entityId: entityId,
    createdAt: createdAt,
    isRead: isRead ?? this.isRead,
  );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        kind: json['kind'] as String? ?? 'system',
        entityId: json['entityId'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        isRead: json['isRead'] as bool? ?? false,
      );
}

/// The feed plus its badge count, as one response.
class NotificationFeed {
  const NotificationFeed({required this.unreadCount, required this.items});

  final int unreadCount;
  final List<AppNotification> items;

  static const empty = NotificationFeed(unreadCount: 0, items: []);

  factory NotificationFeed.fromJson(Map<String, dynamic> json) =>
      NotificationFeed(
        unreadCount: json['unreadCount'] as int? ?? 0,
        items: (json['items'] as List? ?? [])
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
