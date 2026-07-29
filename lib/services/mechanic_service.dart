import '../core/api_client.dart';
import '../models/job.dart';
import '../models/photo.dart';

/// Everything the mechanic app asks the server for.
///
/// None of these take a mechanic name — the server scopes every one to the
/// signed-in account, so there is no parameter to get wrong or to tamper with.
class MechanicService {
  MechanicService(this._api);

  final ApiClient _api;

  /// Jobs assigned to the signed-in mechanic.
  ///
  /// [active] hides finished and cancelled work; pass a [status] to narrow to
  /// one. Ordering is the server's: overdue first, then by promised date.
  Future<List<MechanicJob>> jobs({
    String? status,
    bool active = true,
    String? search,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/mechanic/jobs',
      query: {
        'status': status,
        'active': active,
        'search': (search?.isEmpty ?? true) ? null : search,
      },
    );

    return (data['list'] as List)
        .map((e) => MechanicJob.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MechanicSummary> summary() async {
    final data = await _api.get<Map<String, dynamic>>('/mechanic/summary');
    return MechanicSummary.fromJson(data);
  }

  Future<MechanicJob> job(String id) async {
    final data = await _api.get<Map<String, dynamic>>('/mechanic/jobs/$id');
    return MechanicJob.fromJson(data);
  }

  /// Moves a job to a new status, optionally recording the odometer and a work
  /// note. Returns the saved job, so the caller never has to re-read it.
  Future<MechanicJob> updateStatus(
    String id, {
    required String status,
    int? odometer,
    String? note,
  }) async {
    final data = await _api.put<Map<String, dynamic>>(
      '/mechanic/jobs/$id/status',
      body: {
        'status': status,
        // Null-aware value: the whole entry is dropped when odometer is null,
        // which is what the server reads as "leave this field alone".
        'odometer': ?odometer,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );

    return MechanicJob.fromJson(data);
  }

  /// Adds services from the workshop's price list to an assigned job.
  ///
  /// The mechanic chooses *which* service, never what it costs — there is no
  /// price on this request, and the server takes it from the catalogue. The
  /// customer gets a notification, because they are about to be charged more
  /// than they agreed to.
  Future<MechanicJob> addServices(String jobId, List<String> serviceIds) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/mechanic/jobs/$jobId/services',
      body: {'serviceIds': serviceIds},
    );

    return MechanicJob.fromJson(data);
  }

  Future<List<JobPhoto>> photos(String jobId) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/job-cards/$jobId/photos',
    );

    return (data['list'] as List)
        .map((e) => JobPhoto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JobPhoto> uploadPhoto(
    String jobId, {
    required String filePath,
    required String kind,
    String caption = '',
  }) async {
    final data = await _api.upload<Map<String, dynamic>>(
      '/job-cards/$jobId/photos',
      filePath: filePath,
      fieldName: 'file',
      fields: {'kind': kind, 'caption': caption},
    );

    return JobPhoto.fromJson(data);
  }

  Future<void> deletePhoto(String jobId, int photoId) =>
      _api.delete<dynamic>('/job-cards/$jobId/photos/$photoId');
}
