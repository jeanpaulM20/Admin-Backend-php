class ApiConfig {
  static const String baseUrl = 'https://apps.sihltraining.ch/admin/api/';
  static const String salt = r'sKLUIE7dfwo4hn23l;idfj[028325p*^&)(op';
  static const String authHeader = 'X-Auth-Token';

  // Endpoints
  static const String loginTrainer = 'loginTrainer';
  static const String aboutUs = 'trainer/aboutus';
  static const String trainingType = 'training_type';
  static const String locationList = 'location';
  static const String settings = 'settings';
  static const String client = 'client';
  static const String availability = 'avaliability';
  static const String training = 'training';
  static const String cancelTraining = 'cancelTrainingTrainer';
  static const String cancelTrainingTrainer = 'cancelTrainingTrainer';
  static const String inviteTrainingTrainer = 'inviteTrainingTrainer';
  static const String feedback = 'feedback';
  static const String markTrainerFeedback = 'markTrainerFeedback';
  static const String changePassword = 'changePassword';
  static const String preference = 'preference';
}
