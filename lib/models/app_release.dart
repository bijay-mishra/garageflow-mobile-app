/// The newest published build of this app, as the server reports it.
///
/// The comparison is on [latestBuild] and never on [latestVersion]. "1.10.0"
/// sorts before "1.9.0" as text, and every scheme invented to fix that breaks
/// on the first release that does not fit it. A build number — the `+14` in
/// `version: 1.0.0+14`, and the same integer Android calls versionCode — only
/// ever goes up.
class AppRelease {
  const AppRelease({
    required this.latestVersion,
    required this.latestBuild,
    required this.minimumBuild,
    required this.releaseNotes,
    required this.storeUrl,
  });

  /// What to show the customer, e.g. "1.1.0".
  final String latestVersion;

  /// The build number to compare against.
  final int latestBuild;

  /// The oldest build still allowed to carry on without updating.
  final int minimumBuild;

  /// What is new, in a sentence or two. May be empty.
  final String releaseNotes;

  /// Where the Update button goes.
  final String storeUrl;

  /// Nothing published, or a server with nothing to say about versions.
  ///
  /// The same value stands in for both, and deliberately: from the app's side
  /// they are one case — do not prompt — and a nullable release would put a
  /// null check on every caller to express the same thing.
  static const none = AppRelease(
    latestVersion: '',
    latestBuild: 0,
    minimumBuild: 0,
    releaseNotes: '',
    storeUrl: '',
  );

  /// Whether [installedBuild] is behind what has been published.
  bool isNewerThan(int installedBuild) =>
      latestBuild > 0 && installedBuild > 0 && latestBuild > installedBuild;

  /// Whether [installedBuild] is too old to keep using.
  ///
  /// Its prompt has no "later" button. This is for a release that genuinely
  /// broke older apps — an endpoint that moved under them — where carrying on
  /// means failures that look like the app being broken rather than old.
  bool isTooOld(int installedBuild) =>
      minimumBuild > 0 && installedBuild > 0 && installedBuild < minimumBuild;

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
    latestVersion: json['latestVersion'] as String? ?? '',
    // Tolerant of a number arriving as a string, which is what a hand-edited
    // appsettings entry produces and what would otherwise throw on a cast.
    latestBuild: _int(json['latestBuild']),
    minimumBuild: _int(json['minimumBuild']),
    releaseNotes: json['releaseNotes'] as String? ?? '',
    storeUrl: json['storeUrl'] as String? ?? '',
  );

  static int _int(Object? value) => switch (value) {
    int v => v,
    num v => v.toInt(),
    String v => int.tryParse(v) ?? 0,
    _ => 0,
  };
}
