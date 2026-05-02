import 'package:flutter/foundation.dart';
import '../models/invoice.dart';
import '../services/invoice_service.dart';
import '../services/mock_data.dart';

class InvoiceProvider extends ChangeNotifier {
  final InvoiceService _service = InvoiceService();

  bool _isLoading = false;
  String? _error;
  List<Invoice> _data = [];
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Invoice> get data => _data;

  Future<void> fetch(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _data = await _service.listInvoices(clientId);
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
    _data = MockData.invoices;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
