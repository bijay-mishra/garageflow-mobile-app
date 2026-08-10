import '../core/api_client.dart';
import '../models/loyalty.dart';

/// Rewards, offers and star ratings.
///
/// One service for both audiences. A customer reads their own card and leaves
/// ratings; a mechanic reads the score customers gave them. The split is
/// enforced by the server's role checks, not here — this only knows which path
/// answers which question.
class LoyaltyService {
  LoyaltyService(this._api);

  final ApiClient _api;

  /// Where the signed-in customer stands in their current garage's scheme.
  ///
  /// Answers with a card whose flags are both false when the garage runs no
  /// scheme, or when the customer has joined nobody — so callers never have to
  /// treat "no scheme" as an error.
  Future<LoyaltyCard> card() async {
    final data = await _api.get<Map<String, dynamic>>('/customer/loyalty');
    return LoyaltyCard.fromJson(data);
  }

  /// How the stamps and points got to where they are, newest first.
  Future<List<LoyaltyEntry>> history({int take = 30}) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/customer/loyalty/history',
      query: {'take': take},
    );

    return ((data['list'] as List?) ?? const [])
        .map((e) => LoyaltyEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Promotions running today at the current garage.
  ///
  /// Open to any signed-in account, which is why the mechanic app can show the
  /// same strip — a mechanic being asked "is the wash offer still on?" at the
  /// counter should be able to answer.
  Future<List<Offer>> offers() async {
    final data = await _api.get<List<dynamic>>('/offers/running');

    return data.map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The customer's own rating on a job, or null when they have not left one.
  Future<JobRating?> ratingFor(String jobId) async {
    final data = await _api.get<Map<String, dynamic>?>('/customer/jobs/$jobId/rating');
    return data == null ? null : JobRating.fromJson(data);
  }

  /// Leaves or replaces stars on a finished job.
  ///
  /// Rating twice edits the first one rather than failing, so somebody who
  /// changes their mind is not fighting a duplicate.
  Future<JobRating> rate(
    String jobId, {
    required int stars,
    int? mechanicStars,
    String comment = '',
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/customer/jobs/$jobId/rating',
      body: {
        'stars': stars,
        'mechanicStars': mechanicStars,
        'comment': comment.trim(),
      },
    );

    return JobRating.fromJson(data);
  }

  /// The signed-in mechanic's own average. Resolved from their token.
  Future<MechanicRating> myRating() async {
    final data = await _api.get<Map<String, dynamic>>('/ratings/mine');
    return MechanicRating.fromJson(data);
  }
}
