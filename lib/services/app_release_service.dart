import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/app_release.dart';

/// Asks the server which build of this app is the current one.
///
/// Needs no session, and that is the point: the check runs on the way in,
/// before anybody has signed in — and an app old enough that signing in no
/// longer works is exactly the one that most needs to be told to update.
class AppReleaseService {
  AppReleaseService(this._api);

  final ApiClient _api;

  /// The current release, or [AppRelease.none] when there is nothing to say.
  ///
  /// Never throws. Every way this can fail — no network on the way in, a
  /// server too old to have the endpoint, a 204 for a release nobody has
  /// configured — means the same thing to the caller: do not prompt. Letting
  /// any of them surface would turn "we could not check for updates" into an
  /// error dialog over an app that is working perfectly well.
  Future<AppRelease> latest() async {
    try {
      final data = await _api.get<Map<String, dynamic>>(
        '/app/version',
        noAuth: true,
      );

      return AppRelease.fromJson(data);
    } catch (error) {
      debugPrint('Could not check for an update: $error');
      return AppRelease.none;
    }
  }
}
