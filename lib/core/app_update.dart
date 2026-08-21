import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_release.dart';
import '../services/app_release_service.dart';
import 'i18n.dart';
import 'theme.dart';

/// Telling somebody a new version exists, once, without becoming a nag.
///
/// ## Why a snooze rather than a "seen" flag
///
/// A flag shown once is shown once ever, which for an optional update means
/// almost nobody takes it. A dialog on every launch is the other failure and a
/// worse one — people learn to dismiss it without reading, and then dismiss
/// the mandatory one the same way.
///
/// So "Remind me later" buys a day, and the snooze is stored *against the
/// build it dismissed*. A newer build than the one they put off is news again
/// and asks immediately, rather than serving out the remainder of a snooze
/// that was about something else.
///
/// ## What is never snoozed
///
/// A build below the server's minimum. That prompt has no later button at all,
/// because the app is talking to endpoints that have moved under it — carrying
/// on produces failures that read as the app being broken rather than old.
class AppUpdate {
  AppUpdate._();

  static const _snoozeBuildKey = 'update_snoozed_build';
  static const _snoozeUntilKey = 'update_snoozed_until';

  /// How long "Remind me later" lasts.
  ///
  /// Long enough that it is not the same launch, short enough that an optional
  /// update still lands within a week of asking. Next-launch would make the
  /// button a lie; a week would make it a way to never update.
  static const _snooze = Duration(hours: 24);

  /// True once this run has asked, so a rebuild cannot raise a second dialog.
  static bool _askedThisRun = false;

  /// Checks for a newer build and prompts if there is one.
  ///
  /// Silent about everything that is not "there is a newer build and you
  /// should know": no network, no endpoint, nothing published, already up to
  /// date, or asked recently. This runs on the way into the app, and an app
  /// that greets you with a failure to check for updates is worse than one
  /// that quietly does not check.
  static Future<void> promptIfAvailable(
    BuildContext context,
    AppReleaseService service,
  ) async {
    if (_askedThisRun) return;
    _askedThisRun = true;

    final installed = _installedBuild;
    if (installed == 0) return;

    final release = await service.latest();

    final forced = release.isTooOld(installed);
    if (!forced && !release.isNewerThan(installed)) return;

    if (!forced && await _isSnoozed(release.latestBuild)) return;
    if (!context.mounted) return;

    final update = await showDialog<bool>(
      context: context,
      // A forced prompt cannot be dismissed by tapping outside it either.
      // Leaving that gap open would make the whole thing advisory.
      barrierDismissible: !forced,
      builder: (_) => _UpdateDialog(release: release, forced: forced),
    );

    if (update == true) {
      await _openStore(release.storeUrl);
      return;
    }

    // Only an optional prompt can get here — a forced dialog has no way out —
    // but the guard is kept so that stays true if the dialog ever changes.
    if (!forced) await _snoozeUntilTomorrow(release.latestBuild);
  }

  static int _installedBuild = 0;
  static String _installedLabel = '';

  /// This app's own build number, or 0 if it could not be read.
  ///
  /// Zero means "do not prompt" rather than "assume ancient": comparing an
  /// unknown build against anything would either nag everybody or nobody, and
  /// the honest answer to not knowing is to say nothing.
  static int get installedBuild => _installedBuild;

  /// The installed version as people write it, e.g. "1.0.0 (14)".
  ///
  /// Read from the bundle rather than typed into a constant. The feedback
  /// screen puts this in every bug report, and a hardcoded string there is one
  /// somebody has to remember to bump twice — it goes stale on the first
  /// release where they forget, and then every report for the next year names
  /// the wrong version.
  static String get installedLabel => _installedLabel;

  /// Reads the bundle once, at startup.
  ///
  /// Cached because the two callers want it synchronously — a prompt decided
  /// during a post-frame callback and a line drawn inside a build — and one
  /// plugin call at launch is cheaper than a FutureBuilder in each.
  static Future<void> load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _installedBuild = int.tryParse(info.buildNumber) ?? 0;
      _installedLabel = '${info.version} (${info.buildNumber})';
    } catch (_) {
      // Left at 0 and empty, which both callers already treat as "say nothing".
    }
  }

  static Future<bool> _isSnoozed(int build) async {
    final prefs = await SharedPreferences.getInstance();

    // A different build from the one that was put off. Whatever they dismissed,
    // this is not it.
    if (prefs.getInt(_snoozeBuildKey) != build) return false;

    final until = prefs.getInt(_snoozeUntilKey);
    if (until == null) return false;

    return DateTime.now().millisecondsSinceEpoch < until;
  }

  static Future<void> _snoozeUntilTomorrow(int build) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeBuildKey, build);
    await prefs.setInt(
      _snoozeUntilKey,
      DateTime.now().add(_snooze).millisecondsSinceEpoch,
    );
  }

  static Future<void> _openStore(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    // externalApplication, so the Play Store app opens rather than a web view
    // inside this app — which is where the Update button actually is.
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release, required this.forced});

  final AppRelease release;
  final bool forced;

  @override
  Widget build(BuildContext context) {
    final t = AppText.of(context);
    final palette = AppTheme.of(context);

    // Back gesture included: on Android that pops the dialog, which for a
    // forced update would be the way around it.
    return PopScope(
      canPop: !forced,
      child: AlertDialog(
        icon: Icon(
          Icons.system_update_rounded,
          color: forced ? AppTheme.rose : AppTheme.brand,
          size: 32,
        ),
        title: Text(forced ? t('update.requiredTitle') : t('update.title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              forced
                  ? t('update.requiredBody')
                  : t('update.body', [release.latestVersion]),
            ),
            if (release.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.field,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  release.releaseNotes.trim(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
        actions: [
          // Absent rather than disabled on a forced update. A greyed-out way
          // out still reads as a way out somebody is being denied.
          if (!forced)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(t('update.later')),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('update.now')),
          ),
        ],
      ),
    );
  }
}
