import 'dart:io' show HandshakeException;

import 'package:dio/dio.dart';

/// A failed request, already turned into something worth showing a user.
///
/// The API answers every call — success or failure — with
/// `{ data, status, message }`, and `message` is written to be read by a
/// person. So the rule in this app is: show `message`, never a status code and
/// never a raw exception string.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.fieldErrors});

  final String message;
  final int? statusCode;

  /// Field name → messages, when the failure was validation.
  final Map<String, List<String>>? fieldErrors;

  /// True when the request never reached the server: no wifi, wrong host,
  /// server not running. Worth distinguishing because the fix is different —
  /// the user can retry a timeout, but not a 403.
  bool get isConnectionProblem => statusCode == null;

  /// Builds the message a user should see out of whatever Dio produced.
  factory ApiException.from(DioException error) {
    final response = error.response;
    final data = response?.data;

    // The server's own wording wins whenever there is one.
    if (data is Map && data['message'] is String) {
      final raw = data['errors'];
      return ApiException(
        data['message'] as String,
        statusCode: response?.statusCode,
        fieldErrors: raw is Map
            ? raw.map(
                (key, value) => MapEntry(
                  key.toString(),
                  (value as List).map((e) => e.toString()).toList(),
                ),
              )
            : null,
      );
    }

    // A TLS failure has to be peeled off before the switch below. Dio reports a
    // rejected certificate as `unknown` wrapping a HandshakeException as often
    // as it reports `badCertificate`, and `unknown` with no response falls all
    // the way through to "Something went wrong" — which is how the single most
    // diagnosable failure the app has came to be its vaguest message. Android
    // validates against the system root store and offers no way past it, so a
    // self-signed certificate, or a chain served without its intermediate,
    // fails every request on the phone while the same URL loads in a browser
    // the user clicked through weeks ago.
    if (error.type == DioExceptionType.badCertificate ||
        error.error is HandshakeException) {
      return ApiException(
        'The workshop server\'s security certificate is not trusted, so the app '
        'will not connect to it. This is a setting on the server, not on your '
        'phone.',
        statusCode: response?.statusCode,
      );
    }

    final message = switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The workshop server took too long to answer. Check your connection and try again.',
      DioExceptionType.connectionError =>
        'Could not reach the workshop server. Check your connection, or ask the '
            'workshop whether the server is running.',
      DioExceptionType.cancel => 'Request cancelled.',
      // `int?` cannot be compared with `>=`, so the null case is peeled off
      // first and the rest matches against a non-nullable code.
      _ => switch (response?.statusCode ?? 0) {
        401 => 'Your session has expired. Please sign in again.',
        403 => 'You do not have permission to do that.',
        404 => 'That was not found.',
        413 => 'That file is too large to upload.',
        >= 500 => 'The workshop server hit a problem. Please try again.',
        _ => 'Something went wrong. Please try again.',
      },
    };

    return ApiException(message, statusCode: response?.statusCode);
  }

  @override
  String toString() => message;
}
