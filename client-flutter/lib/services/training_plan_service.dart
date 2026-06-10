import '../models/training_plan.dart';
import '../models/subscription.dart';
import '../models/buyable_credit.dart';
import 'api_client.dart';

class TrainingPlanService {
  /// Published plans for the logged-in client (teasers with a lock flag).
  /// The backend derives the client from the auth token.
  Future<List<ClientTrainingPlan>> listPlans() async {
    final data = await apiClient.get('api/training-plan');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(ClientTrainingPlan.fromJson)
          .toList();
    }
    return [];
  }

  /// A single plan — full content when entitled, otherwise a locked teaser.
  Future<ClientTrainingPlan> getPlan(int id) async {
    final data = await apiClient.get('api/training-plan/$id');
    if (data is Map<String, dynamic>) {
      return ClientTrainingPlan.fromJson(data);
    }
    throw ApiException(500, 'Ungültige Antwort vom Server');
  }

  /// Current online-coaching subscription status.
  Future<SubscriptionStatus> getSubscription(String clientId) async {
    final data = await apiClient.get('api/client/subscription/$clientId');
    if (data is Map<String, dynamic>) {
      return SubscriptionStatus.fromJson(data);
    }
    return SubscriptionStatus();
  }

  /// Activate the one-time free 1-month trial (self-service, no payment).
  /// Throws ApiException(409) if already used or an active sub exists.
  Future<SubscriptionStatus> activateTrial(String clientId) async {
    final data = await apiClient.post('api/client/coaching/trial/$clientId');
    if (data is Map<String, dynamic>) {
      return SubscriptionStatus.fromJson(data);
    }
    return SubscriptionStatus();
  }

  /// Coaching subscription tiers (public pricing).
  Future<List<CreditPackage>> listCoachingPackages() async {
    final data = await apiClient.get('api/client/packages?kind=coaching');
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(CreditPackage.fromJson)
          .toList();
    }
    return [];
  }
}
