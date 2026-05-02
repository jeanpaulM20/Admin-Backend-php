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

  Future<List<BuyableCredit>> listBuyableCredits(String clientId) async {
    final data = await apiClient.get('api/client/credits/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(BuyableCredit.fromJson)
          .toList();
    }
    return [];
  }

  Future<bool> buyCredits(String clientId, String creditId) async {
    final data = await apiClient.post('api/client/credits/buy/$clientId/$creditId');
    return data != null;
  }
}
