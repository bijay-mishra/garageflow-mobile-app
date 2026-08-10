import '../core/api_client.dart';
import '../models/plan.dart';

/// What GarageFlow costs, and buying it.
///
/// Listing needs no session: a price list is a public fact, and somebody
/// deciding whether to create an account should be able to see it first. That
/// is also why a failure there is never fatal — the plans screen is an offer,
/// not something the app needs in order to work.
class PlansService {
  PlansService(this._api);

  final ApiClient _api;

  Future<List<Plan>> plans() async {
    final data = await _api.get<List<dynamic>>('/plans', noAuth: true);

    return data.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The plan this account is on, and which wallets can take a payment.
  Future<MyPlan> mine() async {
    final data = await _api.get<Map<String, dynamic>>('/plans/me');
    return MyPlan.fromJson(data);
  }

  /// Opens a payment for a plan and returns where to send the customer.
  ///
  /// No amount goes up. The server reads the price from its own configuration,
  /// because a price the app could name is a price the app could invent.
  Future<PlanCheckout> subscribe({
    required String code,
    required String provider,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/plans/subscribe',
      body: {'code': code, 'provider': provider},
    );

    return PlanCheckout.fromJson(data);
  }

  /// Asks the server whether a plan payment actually settled.
  ///
  /// Called when the app comes back to the foreground: the customer has been
  /// away in a browser, and this is how the app finds out what happened without
  /// a deep link registered on both platforms. Safe to call repeatedly — a
  /// settled payment answers the same way every time.
  ///
  /// Throws [ApiException] carrying the server's own sentence when it has not
  /// settled, which is the message worth showing.
  Future<MyPlan> verify(String reference) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/plans/verify',
      body: {'reference': reference},
    );

    return MyPlan.fromJson(data);
  }
}
