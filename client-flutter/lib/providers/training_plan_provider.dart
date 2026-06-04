import 'package:flutter/foundation.dart';
import '../models/training_plan.dart';
import '../models/subscription.dart';
import '../services/training_plan_service.dart';

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
