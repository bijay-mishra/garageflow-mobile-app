import 'package:flutter_test/flutter_test.dart';
import 'package:garageflow_mobile/models/app_release.dart';

/// The version comparison, which is the part of an update prompt that is
/// usually wrong.
AppRelease release({int latest = 0, int minimum = 0, String version = '1.0.0'}) =>
    AppRelease(
      latestVersion: version,
      latestBuild: latest,
      minimumBuild: minimum,
      releaseNotes: '',
      storeUrl: 'https://example.test',
    );

void main() {
  group('isNewerThan', () {
    test('a higher published build is an update', () {
      expect(release(latest: 20).isNewerThan(14), isTrue);
    });

    test('the same build is not', () {
      expect(release(latest: 14).isNewerThan(14), isFalse);
    });

    test('a lower published build is not', () {
      // Happens to anybody running a build newer than production — an internal
      // tester, or the developer. Prompting them to "update" to an older
      // version is the one outcome nobody wants.
      expect(release(latest: 14).isNewerThan(20), isFalse);
    });

    test('an unconfigured release never prompts', () {
      expect(AppRelease.none.isNewerThan(14), isFalse);
    });

    test('an unknown installed build never prompts', () {
      // Reading the bundle failed. Saying nothing is the honest answer.
      expect(release(latest: 99).isNewerThan(0), isFalse);
    });
  });

  group('isTooOld', () {
    test('below the minimum is forced', () {
      expect(release(latest: 20, minimum: 18).isTooOld(14), isTrue);
    });

    test('exactly the minimum is allowed to carry on', () {
      expect(release(latest: 20, minimum: 18).isTooOld(18), isFalse);
    });

    test('a zero minimum forces nobody', () {
      expect(release(latest: 20).isTooOld(1), isFalse);
    });

    test('an unknown installed build is never forced', () {
      expect(release(latest: 20, minimum: 18).isTooOld(0), isFalse);
    });
  });

  group('fromJson', () {
    test('reads the server shape', () {
      final r = AppRelease.fromJson({
        'latestVersion': '1.1.0',
        'latestBuild': 20,
        'minimumBuild': 18,
        'releaseNotes': 'Queue positions.',
        'storeUrl': 'https://play.google.com/store/apps/details?id=x',
      });

      expect(r.latestVersion, '1.1.0');
      expect(r.latestBuild, 20);
      expect(r.minimumBuild, 18);
      expect(r.releaseNotes, 'Queue positions.');
    });

    test('tolerates a build number sent as a string', () {
      // What a hand-edited appsettings entry produces, and what would
      // otherwise throw on the cast rather than degrade to "no prompt".
      final r = AppRelease.fromJson({'latestBuild': '20'});
      expect(r.latestBuild, 20);
    });

    test('a missing or unreadable field is not an update', () {
      expect(AppRelease.fromJson({}).isNewerThan(14), isFalse);
      expect(AppRelease.fromJson({'latestBuild': 'x'}).latestBuild, 0);
    });

    test('text version numbers are never what is compared', () {
      // The trap this design exists to avoid: "1.10.0" sorts before "1.9.0"
      // as text. The build number says the opposite, and it is the one that
      // decides.
      final r = AppRelease.fromJson({
        'latestVersion': '1.10.0',
        'latestBuild': 30,
      });

      expect('1.10.0'.compareTo('1.9.0') < 0, isTrue, reason: 'text sorts wrong');
      expect(r.isNewerThan(29), isTrue, reason: 'the build number decides');
    });
  });
}
