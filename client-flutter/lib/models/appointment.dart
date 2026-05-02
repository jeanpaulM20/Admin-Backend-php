class Appointment {
  final int id;
  final String date;
  final String timeFrom;
  final String? timeTo;
  final String trainerName;
  final String? trainerPhoto;
  final String typeName;
  final String? location;
  final String? notes;
  final String status;

  Appointment({
    required this.id,
    required this.date,
    required this.timeFrom,
    this.timeTo,
    required this.trainerName,
    this.trainerPhoto,
    required this.typeName,
    this.location,
    this.notes,
    this.status = 'active',
  });

  bool get isCancelled => status == 'cancelled' || status == 'storniert';

  factory Appointment.fromJson(Map<String, dynamic> j) {
    final trainerObj = j['trainer'] as Map<String, dynamic>?;
    String tName = '';
    String? tPhoto;
    if (trainerObj != null) {
      final tf = trainerObj['firstname']?.toString() ?? trainerObj['surname']?.toString() ?? '';
      final tl = trainerObj['lastname']?.toString() ?? trainerObj['name']?.toString() ?? '';
      tName = '$tf $tl'.trim();
      tPhoto = trainerObj['photo']?.toString() ?? trainerObj['picture']?.toString();
    }
    if (tName.isEmpty) {
      tName = j['trainer_name']?.toString() ?? '';
    }

    final typeObj = j['training_type'] as Map<String, dynamic>?;
    final typeName = typeObj?['name']?.toString() ??
        j['type_name']?.toString() ??
        j['training_type_name']?.toString() ?? 'Training';

    final locObj = j['location'] as Map<String, dynamic>?;
    final location = locObj?['name']?.toString() ??
        j['location_name']?.toString() ??
        j['location']?.toString();

    return Appointment(
      id: _parseInt(j['id'] ?? j['appointment_id'] ?? j['training_id'] ?? 0),
      date: j['date']?.toString() ?? '',
      timeFrom: j['time_from']?.toString() ??
          j['starttime']?.toString() ??
          j['from']?.toString() ?? '',
      timeTo: j['time_to']?.toString() ?? j['endtime']?.toString() ?? j['to']?.toString(),
      trainerName: tName,
      trainerPhoto: tPhoto,
      typeName: typeName,
      location: location,
      notes: j['notes']?.toString() ?? j['comment']?.toString(),
      status: j['status']?.toString() ?? 'active',
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
