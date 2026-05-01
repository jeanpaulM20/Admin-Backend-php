class ApiConfig {
  ApiConfig._();

  /// PHP production backend
  static const String baseUrl = 'https://apps.sihltraining.ch/';

  static const String authHeader = 'X-Auth-Token';

  // Auth
  static const String token = 'api/token';

  // Client endpoints (all require X-Auth-Token)
  static String start(int clientId)        => 'api/client/start/$clientId';
  static String calendar(int clientId)     => 'api/client/calendar/$clientId';
  static String profile(int clientId)      => 'api/client/profile/$clientId';
  static String credits(int clientId)      => 'api/client/credits/$clientId';
  static String invoices(int clientId)     => 'api/client/invoices/$clientId';
  static String tests(int clientId)        => 'api/client/tests/$clientId';
  static String bookAppointment(int clientId) => 'api/client/appointment/$clientId';
  static String updateAppointment(int appointmentId) => 'api/client/appointment/$appointmentId';
  static String cancelAppointment(int clientId, int appointmentId) =>
      'api/client/appointment/$clientId/$appointmentId';
}
