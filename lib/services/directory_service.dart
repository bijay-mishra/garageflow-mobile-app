import '../core/api_client.dart';
import '../models/auth_user.dart';
import '../models/workshop_card.dart';

/// The garage directory, and moving between garages.
///
/// The only service in the app whose first call needs no session: somebody
/// deciding whether to install this should be able to see whether any garage
/// near them uses it, before creating an account.
class DirectoryService {
  DirectoryService(this._api);

  final ApiClient _api;

  /// Garages using GarageFlow, nearest first when [latitude] and [longitude]
  /// are given.
  ///
  /// `noAuth` is deliberate on the browse call: it is used from the signup
  /// screen, where there is no token, and sending a stale one would only invite
  /// a pointless refresh attempt.
  Future<List<WorkshopCard>> browse({
    String? search,
    double? latitude,
    double? longitude,
    bool anonymous = false,
  }) async {
    final data = await _api.get<Map<String, dynamic>>(
      '/garages',
      query: {
        'search': (search?.trim().isEmpty ?? true) ? null : search!.trim(),
        'lat': latitude,
        'lng': longitude,
        'take': 50,
      },
      noAuth: anonymous,
    );

    return ((data['list'] as List?) ?? const [])
        .map((e) => WorkshopCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The garages this customer has joined. Primary first.
  Future<List<WorkshopCard>> mine() async {
    final data = await _api.get<List<dynamic>>('/garages/mine');

    return data
        .map((e) => WorkshopCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Joins a garage. Returns the server's own sentence, which differs between
  /// a first join and a second one and is worth showing verbatim.
  Future<String> join(String companyCode) async {
    final response = await _api.postEnvelope(
      '/garages/${companyCode.trim().toUpperCase()}/join',
    );

    return response.message;
  }

  /// Swaps the current token for one scoped to [companyCode].
  ///
  /// This is the hinge the whole multi-garage feature turns on: every other
  /// customer endpoint reads the garage out of the token, so switching is a new
  /// token rather than a parameter threaded through sixty calls.
  Future<AuthResult> selectWorkshop(String companyCode) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/select-workshop',
      body: {'companyCode': companyCode.trim().toUpperCase()},
    );

    return AuthResult.fromJson(data);
  }

  /// Open sign-up. No company code — a person downloading the app has never
  /// heard of one, and the account starts belonging to no garage at all.
  Future<AuthResult> signUp({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/signup',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'password': password,
      },
      noAuth: true,
    );

    return AuthResult.fromJson(data);
  }
}
