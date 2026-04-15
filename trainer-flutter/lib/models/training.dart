class Training {
  final int id;
  final String? title;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? date;
  final String? timeFrom;
  final String? timeTo;
  final int? clientId;
  final String? clientName;
  final int? trainerId;
  final String? trainerName;
  final int? locationId;
  final String? locationName;
  final String? trainingType;
  final String? status;
  final String? notes;
  final bool isCancelled;

  const Training({
    required this.id,
    this.title,
    this.startTime,
    this.endTime,
    this.date,
    this.timeFrom,
    this.timeTo,
    this.clientId,
    this.clientName,
    this.trainerId,
    this.trainerName,
    this.locationId,
    this.locationName,
    this.trainingType,
    this.status,
    this.notes,
    this.isCancelled = false,
  });

  factory Training.fromJson(Map<String, dynamic> json) {
    DateTime? startTime;
    DateTime? endTime;

    // Try to parse combined datetime first
    final startStr = json['start']?.toString() ??
        json['start_time']?.toString() ??
        json['datetime_from']?.toString();
    final endStr = json['end']?.toString() ??
        json['end_time']?.toString() ??
        json['datetime_to']?.toString();

    if (startStr != null) {
      startTime = DateTime.tryParse(startStr);
    }
    if (endStr != null) {
      endTime = DateTime.tryParse(endStr);
    }

    // If no combined datetime, try date + time fields
    if (startTime == null) {
      final date = json['date']?.toString() ?? json['training_date']?.toString();
      final timeFrom = json['time_from']?.toString() ??
          json['from']?.toString() ??
          json['start_time']?.toString();
      if (date != null && timeFrom != null) {
        startTime = DateTime.tryParse('$date $timeFrom');
      }
    }

    final statusStr =
        json['status']?.toString() ?? json['training_status']?.toString();

    return Training(
      id: _parseInt(json['id'] ?? json['training_id'] ?? 0),
      title: json['title']?.toString() ?? json['name']?.toString(),
      startTime: startTime,
      endTime: endTime,
      date: json['date']?.toString() ?? json['training_date']?.toString(),
      timeFrom: json['time_from']?.toString() ?? json['from']?.toString(),
      timeTo: json['time_to']?.toString() ?? json['to']?.toString(),
      clientId: _parseInt(json['client_id']),
      clientName: json['client_name']?.toString() ??
          _buildName(json, 'client_first_name', 'client_last_name'),
      trainerId: _parseInt(json['trainer_id']),
      trainerName: json['trainer_name']?.toString(),
      locationId: _parseInt(json['location_id']),
      locationName: json['location_name']?.toString() ??
          json['location']?.toString(),
      trainingType: json['training_type']?.toString() ??
          json['type']?.toString() ??
          json['type_name']?.toString(),
      status: statusStr,
      notes: json['notes']?.toString() ?? json['comment']?.toString(),
      isCancelled: statusStr?.toLowerCase() == 'cancelled' ||
          statusStr?.toLowerCase() == 'canceled' ||
          (json['is_cancelled'] == true) ||
          (json['cancelled'] == 1) ||
          (json['cancelled'] == true),
    );
  }

  static String? _buildName(Map<String, dynamic> json, String firstKey, String lastKey) {
    final first = json[firstKey]?.toString() ?? '';
    final last = json[lastKey]?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isNotEmpty ? name : null;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String get displayDate {
    if (startTime != null) {
      return '${startTime!.day.toString().padLeft(2, '0')}.${startTime!.month.toString().padLeft(2, '0')}.${startTime!.year}';
    }
    return date ?? 'Unknown date';
  }

  String get displayTime {
    if (startTime != null) {
      final start =
          '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}';
      if (endTime != null) {
        final end =
            '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}';
        return '$start - $end';
      }
      return start;
    }
    if (timeFrom != null) {
      if (timeTo != null) return '$timeFrom - $timeTo';
      return timeFrom!;
    }
    return 'Unknown time';
  }
}
