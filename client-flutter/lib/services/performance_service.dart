import '../models/performance_section.dart';
import '../models/training_review.dart';
import 'api_client.dart';

class PerformanceService {
  Future<List<PerformanceSection>> getPerformanceData(String clientId) async {
    final data = await apiClient.get('api/client/tests/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PerformanceSection.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<PerformanceSection>> getMetrics(String clientId) async {
    final data = await apiClient.get('api/client/metrics/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(PerformanceSection.fromJson)
          .toList();
    }
    return [];
  }

  Future<List<TrainingReview>> getReviews(String clientId) async {
    final data = await apiClient.get('api/client/reviews/$clientId');
    if (data == null) return [];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(TrainingReview.fromJson)
          .toList();
    }
    return [];
  }
}
