import 'package:flutter/foundation.dart';
import '../models/profile_data.dart';
import '../models/invoice.dart';
import '../models/client_file.dart';
import '../services/profile_service.dart';
import '../services/api_client.dart';
import '../services/mock_data.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileService _service = ProfileService();

  bool _isLoading = false;
  String? _error;
  ProfileData? _data;
  List<Invoice> _invoices = [];
  List<ClientFile> _files = [];
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  ProfileData? get data => _data;
  List<Invoice> get invoices => _invoices;
  List<ClientFile> get files => _files;

  Future<void> fetch(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Run all three requests in parallel — each one independently resilient
    final results = await Future.wait([
      _fetchProfile(clientId),
      _fetchInvoices(clientId),
      _fetchFiles(clientId),
    ]);

    // Profile is the primary data — if it failed, surface the error
    if (results[0] != null) {
      _error = results[0];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Returns error message or null on success
  Future<String?> _fetchProfile(String clientId) async {
    try {
      _data = await _service.getProfile(clientId);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  Future<String?> _fetchInvoices(String clientId) async {
    try {
      final data = await apiClient.get('api/client/invoices/$clientId');
      if (data is List) {
        _invoices = data
            .whereType<Map<String, dynamic>>()
            .map(Invoice.fromJson)
            .toList();
      }
      return null;
    } catch (_) {
      return null; // Invoices are non-critical
    }
  }

  Future<String?> _fetchFiles(String clientId) async {
    try {
      final data = await apiClient.get('api/client/files/$clientId');
      if (data is List) {
        _files = data
            .whereType<Map<String, dynamic>>()
            .map(ClientFile.fromJson)
            .toList();
      }
      return null;
    } catch (_) {
      return null; // Files are non-critical
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void loadMockData() {
    _isMock = true;
    _data = MockData.profileData;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
