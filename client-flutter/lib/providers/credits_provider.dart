import 'package:flutter/foundation.dart';
import '../models/buyable_credit.dart';
import '../services/credits_service.dart';
import '../services/mock_data.dart';

class CreditsProvider extends ChangeNotifier {
  final CreditsService _service = CreditsService();

  bool _isLoading = false;
  String? _error;
  List<BuyableCredit> _data = [];
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BuyableCredit> get data => _data;

  Future<void> fetch(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _service.listBuyableCredits(clientId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> buy(String clientId, String creditId) async {
    if (_isMock) return true;
    try {
      return await _service.buyCredits(clientId, creditId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadMockData() {
    _isMock = true;
    _data = MockData.buyableCredits;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
