import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'config.dart';
import 'token_storage.dart';

/// The one place an HTTP request is made.
///
/// Mirrors the dashboard's `lib/api-request.ts`: everything goes through here,
/// every response is unwrapped from the `{ data, status, message }` envelope,
/// and every failure arrives as an [ApiException] carrying the server's own
/// sentence. Screens never touch Dio.
class ApiClient {
  ApiClient(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiRoot,
        connectTimeout: AppConfig.requestTimeout,
        receiveTimeout: AppConfig.requestTimeout,
        sendTimeout: AppConfig.requestTimeout,
        headers: {'Accept': 'application/json'},
        // 4xx and 5xx come back as responses rather than throwing, so the
        // interceptor below can decide what to do about a 401 before anyone
        // else sees it.
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(onRequest: _attachToken, onResponse: _handle401),
    );
  }

  final TokenStorage _storage;
  late final Dio _dio;

  /// Called when the session cannot be recovered, so the app can return to the
  /// login screen. Set by AuthController — this layer must not import Flutter.
  void Function()? onSessionExpired;

  /// The refresh in flight, if any.
  ///
  /// A screen fires several requests at once, so an expired token produces a
  /// burst of 401s. They all await this one future — otherwise each would
  /// spend the refresh token, and the server rotates it on every use, so all
  /// but the first would fail and sign the user out mid-session.
  Future<bool>? _refreshInFlight;

  Future<void> _attachToken(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['noAuth'] != true) {
      final token = await _storage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _handle401(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final isAuthCall = response.requestOptions.extra['noAuth'] == true;

    // A 401 from login means bad credentials, not a dead session. Refreshing
    // would be nonsense, and the server's message should reach the user.
    if (response.statusCode != 401 || isAuthCall) {
      return handler.next(response);
    }

    final refreshed = await (_refreshInFlight ??= _refresh().whenComplete(() {
      _refreshInFlight = null;
    }));

    if (!refreshed) {
      await _storage.clear();
      onSessionExpired?.call();
      return handler.next(response);
    }

    // Replay the original request with the new token.
    try {
      final retry = await _dio.fetch(response.requestOptions);
      return handler.resolve(retry);
    } on DioException catch (error) {
      return handler.next(error.response ?? response);
    }
  }

  Future<bool> _refresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null) return false;

    try {
      // A bare Dio instance on purpose: routing this through _dio would
      // recurse straight back into this interceptor on failure.
      final response = await Dio(
        BaseOptions(baseUrl: AppConfig.apiRoot),
      ).post('/auth/refresh', data: {'refreshToken': refreshToken});

      final data = response.data?['data'];
      if (data is! Map || data['accessToken'] is! String) return false;

      await _storage.saveTokens(
        data['accessToken'] as String,
        data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Verbs ──────────────────────────────────────────────────────────────────
  // Each returns the *payload* — what sits at `data` inside the envelope — so
  // callers never write `response.data['data']`.

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool noAuth = false,
  }) => _send<T>(
    () => _dio.get(
      path,
      queryParameters: _clean(query),
      options: Options(extra: {'noAuth': noAuth}),
    ),
  );

  Future<T> post<T>(String path, {Object? body, bool noAuth = false}) =>
      _send<T>(
        () => _dio.post(
          path,
          data: body,
          options: Options(extra: {'noAuth': noAuth}),
        ),
      );

  /// A POST whose `message` is the point.
  ///
  /// Most calls only want the payload, and the screen writes its own wording.
  /// A few — joining a garage, choosing a handover — have a server that knows
  /// something the client does not: whether this was a first join or a repeat,
  /// whether delivery came out free on this bill. Those sentences are written
  /// to be read by a person, and paraphrasing them here would lose the part
  /// only the server could know.
  Future<ApiEnvelope<T>> postEnvelope<T>(String path, {Object? body}) =>
      _sendEnvelope<T>(() => _dio.post(path, data: body));

  Future<T> put<T>(String path, {Object? body}) =>
      _send<T>(() => _dio.put(path, data: body));

  Future<T> delete<T>(String path) => _send<T>(() => _dio.delete(path));

  /// Multipart upload — one file plus optional text fields.
  Future<T> upload<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, String> fields = const {},
  }) => _send<T>(
    () async => _dio.post(
      path,
      data: FormData.fromMap({
        ...fields,
        fieldName: await MultipartFile.fromFile(filePath),
      }),
      // A photo over a phone connection deserves longer than a JSON call.
      options: Options(sendTimeout: const Duration(minutes: 2)),
    ),
  );

  /// Runs a request, unwraps the envelope, and turns every failure into an
  /// [ApiException].
  Future<T> _send<T>(Future<Response> Function() request) async =>
      (await _sendEnvelope<T>(request)).data;

  /// The same, keeping the server's message alongside the payload.
  Future<ApiEnvelope<T>> _sendEnvelope<T>(
    Future<Response> Function() request,
  ) async {
    try {
      final response = await request();
      final body = response.data;

      // `status` is the API's own flag: 1 success, 0 failure. It is authoritative
      // even on a 200, so it is checked before the status code.
      if (body is Map && body['status'] == 0) {
        final errors = body['errors'];
        throw ApiException(
          body['message'] as String? ?? 'Something went wrong.',
          statusCode: response.statusCode,
          fieldErrors: errors is Map
              ? errors.map(
                  (k, v) => MapEntry(
                    k.toString(),
                    (v as List).map((e) => e.toString()).toList(),
                  ),
                )
              : null,
        );
      }

      if ((response.statusCode ?? 500) >= 400) {
        throw ApiException(
          body is Map
              ? body['message'] as String? ?? 'Something went wrong.'
              : 'Something went wrong.',
          statusCode: response.statusCode,
        );
      }

      return ApiEnvelope<T>(
        data: (body is Map ? body['data'] : body) as T,
        message: body is Map ? body['message'] as String? ?? '' : '',
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  /// Drops null values so an unset filter is absent from the query string
  /// rather than sent as the literal text "null".
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) =>
      query == null ? null : {
        for (final entry in query.entries)
          if (entry.value != null) entry.key: entry.value,
      };
}

/// A payload with the sentence the server sent alongside it.
class ApiEnvelope<T> {
  const ApiEnvelope({required this.data, required this.message});

  final T data;
  final String message;
}
