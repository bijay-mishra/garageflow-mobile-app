import '../core/api_client.dart';
import '../models/auth_user.dart';

/// Sign-in, sign-out and "who am I".
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  /// Signs in. `noAuth` matters: a 401 here means bad credentials, and the
  /// client must show the server's message rather than trying to refresh a
  /// session that was never established.
  Future<AuthResult> login({
    required String companyCode,
    required String email,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: {
        'companyCode': companyCode.trim(),
        'email': email.trim(),
        'password': password,
      },
      noAuth: true,
    );

    return AuthResult.fromJson(data);
  }

  Future<AuthUser> me() async {
    final data = await _api.get<Map<String, dynamic>>('/auth/me');
    return AuthUser.fromJson(data);
  }

  /// Revokes the refresh token server-side. Failure is deliberately swallowed
  /// by the caller: the local session is cleared either way, and a user who
  /// taps sign-out on a dead connection must still end up signed out.
  Future<void> logout(String refreshToken) =>
      _api.post<dynamic>('/auth/logout', body: {'refreshToken': refreshToken});

  Future<void> forgotPassword({
    required String companyCode,
    required String email,
  }) => _api.post<dynamic>(
    '/auth/forgot-password',
    body: {'companyCode': companyCode.trim(), 'email': email.trim()},
    noAuth: true,
  );
}
