import 'appointment.dart';
import 'trainer.dart';
import 'training_type.dart';

class AvailabilityInterval {
  final String id;
  final String trainerId;
  final String date;
  final String from;
  final String to;
  final String? trainingTypeId;
  final String? locationId;

  AvailabilityInterval({
    required this.id,
    required this.trainerId,
    required this.date,
    required this.from,
    required this.to,
    this.trainingTypeId,
    this.locationId,
  });

  factory AvailabilityInterval.fromJson(Map<String, dynamic> json) {
    return AvailabilityInterval(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainer_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      trainingTypeId: json['training_type_id']?.toString(),
      locationId: json['location_id']?.toString(),
    );
  }
}

/// A trainer's existing booking (for buffer/conflict display)
class TrainerBooking {
  final String id;
  final String trainerId;
  final String date;
  final String starttime;
  final int duration;
  final String? locationId;
  final String status;

  TrainerBooking({
    required this.id,
    required this.trainerId,
    required this.date,
    required this.starttime,
    required this.duration,
    this.locationId,
    required this.status,
  });

  factory TrainerBooking.fromJson(Map<String, dynamic> json) {
    return TrainerBooking(
      id: json['id']?.toString() ?? '',
      trainerId: json['trainer_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      starttime: json['starttime']?.toString() ?? '00:00',
      duration: int.tryParse(json['duration']?.toString() ?? '60') ?? 60,
      locationId: json['location_id']?.toString(),
      status: json['status']?.toString() ?? '',
    );
  }
}

class LocationInfo {
  final String id;
  final String name;
  final String? address;

  LocationInfo({required this.id, required this.name, this.address});

  factory LocationInfo.fromJson(Map<String, dynamic> json) {
    return LocationInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString(),
    );
  }
}

class CalendarData {
  final String? defaultTrainerId;
  final String? defaultTypeId;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final int credits;
  final List<Trainer> trainers;
  final List<TrainingType> trainingTypes;
  final List<Appointment> appointments;
  final List<AvailabilityInterval> availabilityIntervals;
  final List<TrainerBooking> trainerBookings;
  final List<LocationInfo> locations;

  CalendarData({
    this.defaultTrainerId,
    this.defaultTypeId,
    this.minimumDate,
    this.maximumDate,
    this.credits = 0,
    required this.trainers,
    required this.trainingTypes,
    required this.appointments,
    required this.availabilityIntervals,
    this.trainerBookings = const [],
    this.locations = const [],
  });

  factory CalendarData.fromJson(Map<String, dynamic> json) {
    final rawTrainers = json['trainers'];
    final trainers = <Trainer>[];
    if (rawTrainers is List) {
      for (final t in rawTrainers) {
        if (t is Map<String, dynamic>) trainers.add(Trainer.fromJson(t));
      }
    }

    final rawTypes = json['training_types'];
    final types = <TrainingType>[];
    if (rawTypes is List) {
      for (final t in rawTypes) {
        if (t is Map<String, dynamic>) types.add(TrainingType.fromJson(t));
      }
    }

    final rawAppts = json['appointments'];
    final appointments = <Appointment>[];
    if (rawAppts is List) {
      for (final a in rawAppts) {
        if (a is Map<String, dynamic>) appointments.add(Appointment.fromJson(a));
      }
    }

    final rawAvail = json['availability'];
    final availability = <AvailabilityInterval>[];
    if (rawAvail is List) {
      for (final a in rawAvail) {
        if (a is Map<String, dynamic>) availability.add(AvailabilityInterval.fromJson(a));
      }
    }

    final rawBookings = json['trainer_bookings'];
    final trainerBookings = <TrainerBooking>[];
    if (rawBookings is List) {
      for (final b in rawBookings) {
        if (b is Map<String, dynamic>) trainerBookings.add(TrainerBooking.fromJson(b));
      }
    }

    final rawLocs = json['locations'];
    final locations = <LocationInfo>[];
    if (rawLocs is List) {
      for (final l in rawLocs) {
        if (l is Map<String, dynamic>) locations.add(LocationInfo.fromJson(l));
      }
    }

    return CalendarData(
      defaultTrainerId: trainers.isNotEmpty ? trainers.first.id : null,
      defaultTypeId: types.isNotEmpty ? types.first.id : null,
      minimumDate: DateTime.now().subtract(const Duration(days: 30)),
      maximumDate: DateTime.now().add(const Duration(days: 90)),
      credits: int.tryParse(json['credits']?.toString() ?? '0') ?? 0,
      trainers: trainers,
      trainingTypes: types,
      appointments: appointments,
      availabilityIntervals: availability,
      trainerBookings: trainerBookings,
      locations: locations,
    );
  }
}
