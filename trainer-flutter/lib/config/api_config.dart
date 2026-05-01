// ignore: avoid_classes_with_only_static_members
class ApiConfig {
  /// Railway NestJS backend
  static const String baseUrl =
      'https://admin-backend-php-production.up.railway.app/api/';

  static const String salt = r'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';
  static const String authHeader = 'X-Auth-Token';

  // Auth & User
  static const String trainerMe         = 'trainer/me';

  // Studio info  (PHP-only — returns 404 on NestJS, handled gracefully)
  static const String aboutUs           = 'trainer/aboutus';

  // Locations
  static const String locationList      = 'location';

  // Clients
  static const String client            = 'client';

  // Trainer availability
  static const String availability      = 'trainer-availability';
  static const String availabilitySerial = 'trainer-availability/serial';

  // Trainings / Appointments
  static const String training          = 'training';

  // Feedback (star ratings from clients)
  static const String feedback          = 'feedback';

  // Training plans
  static const String trainingPlan      = 'training-plan';

  // Performance / metrics
  static const String metric            = 'metric';

  // Performance tests
  static const String performance       = 'performance_test';

  // Anamnese (medical intake questionnaire)
  static const String anamnese          = 'anamnese';

  // Reviews (training recordings with heart rate)
  static const String review            = 'review';

  // ── PHP-legacy endpoints (not yet in NestJS — will return 404) ─────────────
  // These are referenced in screens but not yet implemented in NestJS.
  // They fail gracefully with an error message shown to the user.
  static const String file              = 'file';
  static const String sendFile          = 'file/send';
  static const String trainerQR         = 'trainer/qr';
  static const String preference        = 'preference';
  static const String changePassword    = 'trainer/password';
}
