import '../core/api_client.dart';
import '../models/support.dart';

/// Chat with the garage.
///
/// An assistant answers first and hands anything it cannot to a person at the
/// workshop. The app does not choose which — the server decides whether a
/// question was answerable and escalates on its own, so there is no "ask the
/// bot" versus "ask a human" mode to keep in sync here.
class SupportService {
  SupportService(this._api);

  final ApiClient _api;

  /// This customer's own conversations, newest first.
  Future<List<SupportThread>> threads() async {
    final data = await _api.get<List<dynamic>>('/support/threads');

    return data
        .map((e) => SupportThread.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// One conversation and its messages.
  Future<SupportConversation> conversation(int id) async {
    final data = await _api.get<Map<String, dynamic>>('/support/threads/$id');

    return SupportConversation.fromJson(data);
  }

  /// Opens a conversation with a first question, and returns the answer.
  Future<SupportConversation> start(String message) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/support/threads',
      body: {'message': message},
    );

    return SupportConversation.fromJson(data);
  }

  /// Adds a message to an existing conversation.
  Future<SupportConversation> send(int id, String message) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/support/threads/$id/messages',
      body: {'message': message},
    );

    return SupportConversation.fromJson(data);
  }

  /// Asks for a person.
  ///
  /// Always available, even while the assistant is answering well. A support
  /// screen that makes you argue with a robot before it will fetch somebody is
  /// worse than no support screen.
  Future<SupportConversation> escalate(int id) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/support/threads/$id/escalate',
    );

    return SupportConversation.fromJson(data);
  }
}
