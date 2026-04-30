// ignore: avoid_classes_with_only_static_members
class ApiConfig {
  /// NestJS backend on Railway
  static const String baseUrl = 'https://admin-backend-php-production.up.railway.app/api/';

  static const String salt = r'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';
  static const String authHeader = 'X-Auth-Token';

  // Auth & User — login is now stateless: compute md5(salt+passcode) and call GET trainer/me
  static const String trainerMe           = 'trainer/me';
  static const String preference          = 'preference';
  static const String settings            = 'settings';
  static const String trainerQR           = 'trainer/qr';

  // Trainer list
  static const String trainer             = 'trainer';

  // Studio info
  static const String trainingType        = 'training-type';
  static const String locationList        = 'location';

  // Clients
  static const String client              = 'client';

  // Availability
  static const String availability        = 'trainer-availability';

  // Trainings / Appointments
  static const String training            = 'training';
  static const String cancelTraining      = 'training';

  // Feedback (star ratings from clients)
  static const String feedback            = 'feedback';

  // Training plans
  static const String trainingPlan        = 'training-plan';

  // Performance tests & metrics
  static const String performance         = 'performance-test';
  static const String metric              = 'metric';

  // Exercises
  static const String exercise            = 'exercise';
  static const String exerciseGroups      = 'exercise/groups';

  // About / Studio
  static const String aboutUs             = 'trainer/aboutus';

  // Training actions (use training endpoint + id)
  static const String cancelTrainingTrainer  = 'training';
  static const String inviteTrainingTrainer  = 'training';
  static const String nextTrainerAppointment = 'training';

  // Feedback actions
  static const String markTrainerFeedback = 'feedback';

  // Files
  static const String file                = 'file';
  static const String sendFile            = 'file';

  // Anamnese
  static const String anamnese            = 'anamnese';
  static const String sendAnamnese        = 'anamnese';

  // Training plan actions
  static const String sendTrainingPlan    = 'training-plan';

  // Rates & belt
  static const String ratesAndBelt        = 'trainer/rates-and-belt';

  // Password
  static const String changePassword      = 'trainer/change-password';

  // Availability (extended)
  static const String availabilityFull    = 'trainer-availability/full';
  static const String availabilitySerial  = 'trainer-availability/serial';
  static const String intervalSettings    = 'trainer-availability/interval';
}
