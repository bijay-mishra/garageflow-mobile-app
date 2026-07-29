/// What a photo is showing. Mirrors `Vocabulary.JobPhotoKinds`.
const photoKinds = <String>['before', 'during', 'after', 'damage', 'part'];

/// A photo attached to a job card.
class JobPhoto {
  const JobPhoto({
    required this.id,
    required this.jobCardId,
    required this.url,
    required this.fileName,
    required this.sizeBytes,
    required this.kind,
    required this.caption,
    required this.uploadedBy,
    required this.uploadedAt,
  });

  final int id;
  final String jobCardId;

  /// Absolute and ready for `Image.network` — the server builds it from the
  /// request host, so it is reachable from wherever the app asked.
  final String url;

  final String fileName;
  final int sizeBytes;

  /// One of [photoKinds].
  final String kind;

  final String caption;
  final String uploadedBy;
  final DateTime uploadedAt;

  factory JobPhoto.fromJson(Map<String, dynamic> json) => JobPhoto(
    id: json['id'] as int,
    jobCardId: json['jobCardId'] as String? ?? '',
    url: json['url'] as String? ?? '',
    fileName: json['fileName'] as String? ?? '',
    sizeBytes: json['sizeBytes'] as int? ?? 0,
    kind: json['kind'] as String? ?? 'during',
    caption: json['caption'] as String? ?? '',
    uploadedBy: json['uploadedBy'] as String? ?? '',
    uploadedAt: DateTime.parse(json['uploadedAt'] as String),
  );
}
