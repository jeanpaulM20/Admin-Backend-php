import 'package:flutter/foundation.dart';
import '../models/training_plan.dart';
import '../models/subscription.dart';
import '../services/training_plan_service.dart';
import '../services/api_client.dart';

class TrainingPlanProvider extends ChangeNotifier {
  final TrainingPlanService _service = TrainingPlanService();

  bool _isLoading = false;
  String? _error;
  List<ClientTrainingPlan> _plans = [];
  SubscriptionStatus _subscription = SubscriptionStatus();
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ClientTrainingPlan> get plans => _plans;
  SubscriptionStatus get subscription => _subscription;
  bool get hasActiveSubscription => _subscription.active;

  Future<void> fetch(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.listPlans(),
        _service.getSubscription(clientId),
      ]);
      _plans = results[0] as List<ClientTrainingPlan>;
      _subscription = results[1] as SubscriptionStatus;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Activates the one-time free trial and refreshes subscription state.
  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> activateTrial(String clientId) async {
    if (_isMock) return null;
    try {
      _subscription = await _service.activateTrial(clientId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadMockData() {
    _isMock = true;
    _plans = [];
    _subscription = SubscriptionStatus();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
