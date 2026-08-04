/// A support conversation, as a list shows it.
class SupportThread {
  const SupportThread({
    required this.id,
    required this.subject,
    required this.status,
    required this.preview,
    required this.messageCount,
    required this.lastMessageAt,
    required this.escalatedAt,
  });

  final int id;
  final String subject;

  /// `bot`, `waiting`, `answered` or `closed`.
  final String status;

  final String preview;
  final int messageCount;
  final DateTime lastMessageAt;

  /// Null while the assistant is still handling it.
  final DateTime? escalatedAt;

  /// True once a person at the garage owes a reply.
  bool get waitingOnGarage => status == 'waiting';

  factory SupportThread.fromJson(Map<String, dynamic> json) => SupportThread(
    id: (json['id'] as num?)?.toInt() ?? 0,
    subject: json['subject'] as String? ?? '',
    status: json['status'] as String? ?? 'bot',
    preview: json['preview'] as String? ?? '',
    messageCount: (json['messageCount'] as num?)?.toInt() ?? 0,
    lastMessageAt:
        DateTime.tryParse(json['lastMessageAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    escalatedAt: DateTime.tryParse(
      json['escalatedAt'] as String? ?? '',
    )?.toLocal(),
  );
}

/// One message in a conversation.
class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.sender,
    required this.senderName,
    required this.body,
    required this.source,
    required this.createdAt,
  });

  final int id;

  /// `customer`, `staff`, `operator` or `bot`.
  final String sender;

  final String senderName;
  final String body;

  /// For a bot message: `faq`, `ai`, or `none`. Null for a person.
  final String? source;

  final DateTime createdAt;

  bool get fromMe => sender == 'customer';
  bool get fromBot => sender == 'bot';

  /// True when this answer was generated rather than written by a person.
  ///
  /// Labelled in the UI on purpose: a scripted answer is reliable, a generated
  /// one is a good guess, and showing them identically would be the misleading
  /// choice.
  bool get isGenerated => fromBot && source == 'ai';

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: (json['id'] as num?)?.toInt() ?? 0,
    sender: json['sender'] as String? ?? 'bot',
    senderName: json['senderName'] as String? ?? '',
    body: json['body'] as String? ?? '',
    source: json['source'] as String?,
    createdAt:
        DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );
}

/// A thread and everything said in it.
class SupportConversation {
  const SupportConversation({
    required this.thread,
    required this.messages,
    required this.botActive,
  });

  final SupportThread thread;
  final List<SupportMessage> messages;

  /// False once a person at the garage owns the thread — the assistant then
  /// stays out of it, and the app stops offering to fetch a human.
  final bool botActive;

  factory SupportConversation.fromJson(Map<String, dynamic> json) =>
      SupportConversation(
        thread: SupportThread.fromJson(
          json['thread'] as Map<String, dynamic>? ?? const {},
        ),
        messages: ((json['messages'] as List?) ?? const [])
            .map((e) => SupportMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        botActive: json['botActive'] as bool? ?? true,
      );
}
