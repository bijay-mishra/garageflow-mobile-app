import '../core/api_client.dart';
import '../models/invoice.dart';

/// Bills, paying them, and the workshop's own details.
///
/// The payment flow is deliberately three small calls rather than one clever
/// one. The middle step happens on eSewa's or Khalti's own page, in a browser
/// the app does not control, so the app can only ever say "start this" and later
/// "what happened to it".
class BillingService {
  BillingService(this._api);

  final ApiClient _api;

  /// The signed-in customer's bills, newest first.
  Future<List<Invoice>> invoices() async {
    final data = await _api.get<Map<String, dynamic>>('/customer/invoices');

    return (data['list'] as List)
        .map((e) => Invoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The workshop — address, hours, map pin, and which wallets it can take.
  Future<Workshop> workshop() async {
    final data = await _api.get<Map<String, dynamic>>('/workshop');
    return Workshop.fromJson(data);
  }

  /// Opens a payment attempt and returns where to send the customer.
  Future<PaymentStart> startPayment({
    required String invoiceId,
    required String provider,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/payments/start',
      body: {'invoiceId': invoiceId, 'provider': provider},
    );

    return PaymentStart.fromJson(data);
  }

  /// Asks the server whether an attempt actually settled.
  ///
  /// Called when the app comes back to the foreground: the customer has been
  /// away in a browser, and this is how the app finds out what happened without
  /// needing a deep link registered on both platforms. Safe to call repeatedly —
  /// a settled payment answers the same way every time.
  ///
  /// Throws [ApiException] with the server's own sentence when the payment has
  /// not settled, which is the message worth showing.
  Future<void> verifyPayment(String reference) =>
      _api.post<dynamic>('/payments/verify', body: {'reference': reference});
}
