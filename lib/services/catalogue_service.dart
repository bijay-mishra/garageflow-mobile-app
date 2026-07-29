import '../core/api_client.dart';
import '../models/service.dart';

/// The workshop's price list.
///
/// Shared by both sides of the app because both need it: a customer picking
/// extras when booking, a mechanic adding a wash to a job in front of them. The
/// server decides what each of them is allowed to see — a customer never
/// receives a retired or shop-only row, whatever they ask for.
class CatalogueService {
  CatalogueService(this._api);

  final ApiClient _api;

  /// Everything on offer, cheapest call the app makes.
  ///
  /// [vehicleType] narrows to what suits that body class; services with no
  /// restriction always come back. Filtering server-side rather than in the app
  /// keeps the rule in one place — a bike wash and a bus wash are different
  /// rows, and which one applies is not the app's judgement to make.
  Future<List<WorkshopService>> services({
    String? vehicleType,
    String? category,
    String? search,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/services',
      query: {
        'vehicleType': vehicleType,
        'category': category,
        'search': (search?.isEmpty ?? true) ? null : search,
        'activeOnly': true,
      },
    );

    return (data['list'] as List)
        .map((e) => WorkshopService.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
