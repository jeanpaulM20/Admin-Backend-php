import 'package:flutter/foundation.dart';
import '../models/appointment.dart';
import '../models/calendar_data.dart';
import '../services/appointment_service.dart';
import '../services/mock_data.dart';

class AppointmentProvider extends ChangeNotifier {
  final AppointmentService _service = AppointmentService();

  bool _isLoading = false;
  String? _error;
  StartData? _startData;
  CalendarData? _calendarData;
  bool _isMock = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  StartData? get startData => _startData;
  CalendarData? get calendarData => _calendarData;

  Future<void> fetchStart(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _startData = await _service.getStartData(clientId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchCalendar(String clientId) async {
    if (_isMock) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _calendarData = await _service.getCalendarData(clientId);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> bookAppointment(
    String clientId, {
    required String trainerId,
    required String trainingTypeId,
    required String date,
    required String starttime,
    String? locationId,
    int duration = 60,
  }) async {
    try {
      await _service.bookAppointment(
        clientId,
        trainerId: trainerId,
        trainingTypeId: trainingTypeId,
        date: date,
        starttime: starttime,
        locationId: locationId,
        duration: duration,
      );
      // Refresh data
      await Future.wait([
        fetchStart(clientId),
        fetchCalendar(clientId),
      ]);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelAppointment(String clientId, String appointmentId) async {
    try {
      final success =
          await _service.cancelAppointment(clientId, appointmentId);
      if (success) {
        await Future.wait([
          fetchStart(clientId),
          fetchCalendar(clientId),
        ]);
      }
      return success;
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
    _startData = MockData.startData;
    _calendarData = MockData.calendarData;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
