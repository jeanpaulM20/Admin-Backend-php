import 'package:flutter/foundation.dart';
import '../models/performance_section.dart';
import '../models/training_review.dart';
import '../services/performance_service.dart';
import '../services/mock_data.dart';

class PerformanceProvider extends ChangeNotifier {
  final PerformanceService _service = PerformanceService();

  bool _isLoading = false;
  String? _error;
  List<PerformanceSection> _data = [];
  List<TrainingReview> _reviews = [];
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<PerformanceSection> get data => _data;
  List<TrainingReview> get reviews => _reviews;

  Future<void> fetch(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _service.getPerformanceData(clientId),
        _service.getReviews(clientId),
      ]);
      _data = results[0] as List<PerformanceSection>;
      _reviews = results[1] as List<TrainingReview>;
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
    _data = MockData.performanceData;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
