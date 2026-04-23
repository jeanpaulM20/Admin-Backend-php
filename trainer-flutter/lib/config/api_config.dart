// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;

// ignore: avoid_classes_with_only_static_members
class ApiConfig {
  /// API base URL — resolved dynamically from the browser origin.
  /// On localhost the serve_web.js proxy forwards /admin/api/* to production.
  /// On production (apps.sihltraining.ch) the path resolves directly.
  static String get baseUrl {
    try {
      final origin = html.window.location.origin;
      return '$origin/admin/api/';
    } catch (_) {
      return 'https://apps.sihltraining.ch/admin/api/';
    }
  }

  static const String salt = r'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';
  static const String authHeader = 'X-Auth-Token';

  // Auth & User
  static const String loginTrainer        = 'loginTrainer';
  static const String changePassword      = 'changePassword';
  static const String preference          = 'preference';
  static const String settings            = 'settings';
  static const String trainerQR           = 'trainerQR';

  // Studio info
  static const String aboutUs             = 'trainer/aboutus';
  static const String trainingType        = 'training_type';
  static const String locationList        = 'location/list';

  // Clients
  static const String client              = 'client';

  // Availability
  /// Note: PHP spells it "avaliability" (typo preserved intentionally)
  static const String availability        = 'avaliability';
  static const String availabilityFull    = 'fullAvaliability';
  static const String availabilitySerial  = 'saveSerialAvalibility';
  static const String intervalSettings    = 'saveIntervalSettings';

  // Trainings / Appointments
  static const String training            = 'training';
  static const String cancelTraining        = 'cancelTrainingTrainer';
  static const String cancelTrainingTrainer = 'cancelTrainingTrainer';
  static const String inviteTrainingTrainer = 'inviteTrainingTrainer';
  static const String nextTrainerAppointment = 'nextTrainerAppointment';

  // Feedback (star ratings from clients)
  static const String feedback            = 'feedback';
  static const String markTrainerFeedback = 'markTrainerFeedback';

  // Anamnese (health questionnaire)
  static const String anamnese            = 'anamnese';
  static const String sendAnamnese        = 'sendAnamnese';

  // Training plans
  static const String trainingPlan        = 'trainingplan';
  static const String sendTrainingPlan    = 'sendPlan';

  // Performance tests & metrics
  static const String performance         = 'performance_test';
  static const String metric              = 'metric';

  // Files
  static const String file                = 'file';
  static const String sendFile            = 'sendFile';

  // Rates & belt (heart rate device)
  static const String ratesAndBelt        = 'saveRatesAndBelt';
}
