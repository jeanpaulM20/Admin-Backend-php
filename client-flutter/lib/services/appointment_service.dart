import '../models/appointment.dart';
import '../models/calendar_data.dart';
import 'api_client.dart';

class AppointmentService {
  Future<StartData> getStartData(String clientId) async {
    final data = await apiClient.get('api/client/start/$clientId');
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(500, 'Ungültige Startdaten');
    }
    return StartData.fromJson(data);
  }

  Future<CalendarData> getCalendarData(String clientId) async {
    final data = await apiClient.get('api/client/calendar/$clientId');
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(500, 'Ungültige Kalenderdaten');
    }
    return CalendarData.fromJson(data);
  }

  Future<Map<String, dynamic>> bookAppointment(
    String clientId, {
    required String trainerId,
    required String trainingTypeId,
    required String date,
    required String starttime,
    String? locationId,
    required int duration,
  }) async {
    final body = <String, dynamic>{
      'trainer_id': int.tryParse(trainerId) ?? trainerId,
      'training_type_id': int.tryParse(trainingTypeId) ?? trainingTypeId,
      'date': date,
      'starttime': starttime,
      'duration': duration,
    };
    if (locationId != null && locationId.isNotEmpty) {
      body['location_id'] = int.tryParse(locationId) ?? locationId;
    }
    final data = await apiClient.post(
      'api/client/appointment/$clientId',
      body: body,
    );
    return data is Map<String, dynamic> ? data : {};
  }

  /// Returns the full response map on success (includes `creditRefunded`), null on failure.
  Future<Map<String, dynamic>?> cancelAppointment(String clientId, String appointmentId) async {
    final data = await apiClient
        .delete('api/client/appointment/$clientId/$appointmentId');
    if (data != null && data['success'] == true) return data;
    return null;
  }
}
