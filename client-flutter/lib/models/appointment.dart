class Appointment {
  final String id;
  final DateTime startDate;
  final int duration;
  final String text;
  final String trainingTypeId;
  final String trainingTypeName;
  final String locationId;
  final String locationName;
  final String trainerId;
  final String trainerName;
  final int creditsCharged;
  final String status;

  Appointment({
    required this.id,
    required this.startDate,
    required this.duration,
    required this.text,
    required this.trainingTypeId,
    required this.trainingTypeName,
    required this.locationId,
    required this.locationName,
    required this.trainerId,
    required this.trainerName,
    required this.creditsCharged,
    required this.status,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    // Combine date + starttime from NestJS backend
    DateTime parseDate() {
      final date = json['date']?.toString() ?? '';
      final time = json['starttime'] ?? json['time_from'] ?? '00:00';
      if (date.isEmpty) return DateTime(1970);
      try {
        return DateTime.parse('${date}T$time');
      } catch (_) {
        return DateTime.tryParse(date) ?? DateTime(1970);
      }
    }

    final trainer = json['trainer'];
    String trainerName = '';
    if (trainer is Map<String, dynamic>) {
      trainerName =
          '${trainer['firstname'] ?? ''} ${trainer['lastname'] ?? ''}'.trim();
    }

    return Appointment(
      id: json['id']?.toString() ?? '',
      startDate: parseDate(),
      duration: int.tryParse(json['duration']?.toString() ?? '60') ?? 60,
      text: json['notes']?.toString() ?? json['text']?.toString() ?? '',
      trainingTypeId: json['training_type_id']?.toString() ?? '',
      trainingTypeName: json['training_type_name']?.toString() ?? '',
      locationId: json['location_id']?.toString() ?? '',
      locationName: json['location_name']?.toString() ?? '',
      trainerId: json['trainer_id']?.toString() ?? '',
      trainerName: trainerName,
      creditsCharged:
          int.tryParse(json['credits_charged']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}

/// Data returned by /api/client/start/:id
class StartData {
  final String firstName;
  final String lastName;
  final int totalCredits;
  final List<Appointment> appointments;
  final String? lastTrainingDate;
  final int trainingsThisWeek;

  StartData({
    required this.firstName,
    required this.lastName,
    this.totalCredits = 0,
    required this.appointments,
    this.lastTrainingDate,
    this.trainingsThisWeek = 0,
  });

  factory StartData.fromJson(Map<String, dynamic> json) {
    final rawAppts = json['appointments'];
    final appointments = <Appointment>[];
    if (rawAppts is List) {
      for (final a in rawAppts) {
        if (a is Map<String, dynamic>) {
          appointments.add(Appointment.fromJson(a));
        }
      }
    }
    return StartData(
      firstName: json['firstName']?.toString() ?? json['firstname']?.toString() ?? '',
      lastName: json['lastName']?.toString() ?? json['lastname']?.toString() ?? '',
      totalCredits: int.tryParse(json['credits']?.toString() ?? '0') ?? 0,
      appointments: appointments,
      lastTrainingDate: json['lastTrainingDate']?.toString(),
      trainingsThisWeek: int.tryParse(json['trainingsThisWeek']?.toString() ?? '0') ?? 0,
    );
  }
}
