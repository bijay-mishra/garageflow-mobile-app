package com.codecraft.garageflow

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity, not FlutterActivity.
 *
 * `local_auth` puts up the system biometric prompt, and that prompt is a
 * androidx fragment — it needs a FragmentManager to attach to. Under plain
 * FlutterActivity there is none, and the fingerprint app-lock on the Security
 * screen fails with `no_fragment_activity` at the moment the user turns it on.
 *
 * FragmentActivity does not require an AppCompat theme (only AppCompatActivity
 * does), so LaunchTheme and NormalTheme carry over untouched.
 */
class MainActivity : FlutterFragmentActivity()
