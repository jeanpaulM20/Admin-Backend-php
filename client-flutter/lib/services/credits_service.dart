import '../models/buyable_credit.dart';
import 'api_client.dart';

class CreditsService {
  /// Fetch client's owned credit packs
  Future<List<ClientCredit>> listClientCredits(String clientId) async {
    final data = await apiClient.get('api/client/credits/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ClientCredit.fromJson)
          .toList();
    }
    return [];
  }

  /// Fetch all available packages — credit packs + coaching abos combined
  Future<List<CreditPackage>> listPackages() async {
    final results = await Future.wait([
      apiClient.get('api/client/packages'),              // kind=credits (default)
      apiClient.get('api/client/packages?kind=coaching'), // coaching tiers
    ]);
    final combined = <CreditPackage>[];
    for (final data in results) {
      if (data is List) {
        combined.addAll(data
            .whereType<Map<String, dynamic>>()
            .map(CreditPackage.fromJson));
      }
    }
    return combined;
  }

  /// Purchase a credit package
  Future<Map<String, dynamic>> purchasePackage(String clientId, String packageId) async {
    final data = await apiClient.post(
      'api/client/purchase/$clientId',
      body: {'packageId': int.parse(packageId)},
    );
    if (data is Map<String, dynamic>) return data;
    return {'success': false, 'message': 'Unbekannter Fehler'};
  }
}
