class AvailabilitySlot {
  final int id;
  final String? date;
  final String? timeFrom;
  final String? timeTo;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? trainerId;
  final String? trainerName;
  final int? locationId;
  final String? locationName;
  final bool isBooked;
  final String? status;

  const AvailabilitySlot({
    required this.id,
    this.date,
    this.timeFrom,
    this.timeTo,
    this.startTime,
    this.endTime,
    this.trainerId,
    this.trainerName,
    this.locationId,
    this.locationName,
    this.isBooked = false,
    this.status,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    DateTime? startTime;
    DateTime? endTime;

    final startStr = json['start']?.toString() ??
        json['start_time']?.toString() ??
        json['datetime_from']?.toString();
    final endStr = json['end']?.toString() ??
        json['end_time']?.toString() ??
        json['datetime_to']?.toString();

    if (startStr != null) startTime = DateTime.tryParse(startStr);
    if (endStr != null) endTime = DateTime.tryParse(endStr);

    if (startTime == null) {
      final date = json['date']?.toString();
      final timeFrom = json['time_from']?.toString() ??
          json['from']?.toString();
      if (date != null && timeFrom != null) {
        startTime = DateTime.tryParse('$date $timeFrom');
      }
    }

    final statusStr = json['status']?.toString();
    final isBooked = statusStr == 'booked' ||
        statusStr == 'reserved' ||
        json['is_booked'] == true ||
        json['booked'] == 1 ||
        json['booked'] == true;

    return AvailabilitySlot(
      id: _parseInt(json['id'] ?? json['availability_id'] ?? 0),
      date: json['date']?.toString(),
      timeFrom: json['time_from']?.toString() ??
          json['from']?.toString(),
      timeTo: json['time_to']?.toString() ??
          json['to']?.toString(),
      startTime: startTime,
      endTime: endTime,
      trainerId: _parseInt(json['trainer_id'] ?? json['trainerId']),
      trainerName: json['trainer_name']?.toString() ?? json['trainerName']?.toString(),
      locationId: _parseInt(json['location_id'] ?? json['locationId']),
      locationName: json['location_name']?.toString() ??
          json['location']?.toString(),
      isBooked: isBooked,
      status: statusStr,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
    return '';
  }

  DateTime? get slotDate {
    if (startTime != null) {
      return DateTime(startTime!.year, startTime!.month, startTime!.day);
    }
    if (date != null) {
      return DateTime.tryParse(date!);
    }
    return null;
  }
}

class Location {
  final int id;
  final String name;
  final String? address;
  final String? description;

  const Location({
    required this.id,
    required this.name,
    this.address,
    this.description,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ??
          json['location_name']?.toString() ??
          '',
      address: json['address']?.toString(),
      description: json['description']?.toString(),
    );
  }
}
