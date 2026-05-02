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

    try {
      _data = await _service.getProfile(clientId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    }

    // Load invoices independently - failure does not block the rest
    await Future(() async {
      try {
        final data = await apiClient.get('api/client/invoices/$clientId');
        if (data is List) {
          _invoices = data
              .whereType<Map<String, dynamic>>()
              .map(Invoice.fromJson)
              .toList();
        }
      } catch (_) {}
    });

    // Load files independently - failure does not block the rest
    await Future(() async {
      try {
        final data = await apiClient.get('api/client/files/$clientId');
        if (data is List) {
          _files = data
              .whereType<Map<String, dynamic>>()
              .map(ClientFile.fromJson)
              .toList();
        }
      } catch (_) {}
    });

    _isLoading = false;
    notifyListeners();
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
