import '../models/appointment.dart';
import '../models/calendar_data.dart';
import 'api_client.dart';

class AppointmentService {
  Future<StartData> getStartData(String clientId) async {
    final data = await apiClient.get('api/client/start/$clientId');
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(500, 'Ungueltige Startdaten');
    }
    return StartData.fromJson(data);
  }

  Future<CalendarData> getCalendarData(String clientId) async {
    final data = await apiClient.get('api/client/calendar/$clientId');
    if (data == null || data is! Map<String, dynamic>) {
      throw ApiException(500, 'Ungueltige Kalenderdaten');
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
    int duration = 60,
  }) async {
    final data = await apiClient.post(
      'api/client/appointment/$clientId',
      body: {
        'trainer_id': int.tryParse(trainerId) ?? trainerId,
        'training_type_id': int.tryParse(trainingTypeId) ?? trainingTypeId,
        'location_id': int.tryParse(locationId ?? '1') ?? 1,
        'date': date,
        'starttime': starttime,
        'duration': duration,
      },
    );
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> cancelAppointment(String clientId, String appointmentId) async {
    final data = await apiClient
        .delete('api/client/appointment/$clientId/$appointmentId');
    return data != null && data['success'] == true;
  }
}
