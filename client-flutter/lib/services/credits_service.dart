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

  /// Fetch available credit packages (pricing from website)
  Future<List<CreditPackage>> listPackages() async {
    final data = await apiClient.get('api/client/packages');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(CreditPackage.fromJson)
          .toList();
    }
    return [];
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
