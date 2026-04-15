import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/trainer.dart';
import '../models/client.dart';
import '../models/training.dart';
import '../models/availability.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class TrainerProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // About us / studio info
  AboutUsInfo? _aboutUsInfo;
  bool _aboutUsLoading = false;
  String? _aboutUsError;

  // Clients
  List<Client> _clients = [];
  bool _clientsLoading = false;
  String? _clientsError;

  // Trainings
  List<Training> _trainings = [];
  bool _trainingsLoading = false;
  String? _trainingsError;

  // Availability
  Map<DateTime, List<AvailabilitySlot>> _availabilityMap = {};
  bool _availabilityLoading = false;
  String? _availabilityError;

  // Locations
  List<Location> _locations = [];

  // Getters
  AboutUsInfo? get aboutUsInfo => _aboutUsInfo;
  bool get aboutUsLoading => _aboutUsLoading;
  String? get aboutUsError => _aboutUsError;

  List<Client> get clients => _clients;
  bool get clientsLoading => _clientsLoading;
  String? get clientsError => _clientsError;

  List<Training> get trainings => _trainings;
  bool get trainingsLoading => _trainingsLoading;
  String? get trainingsError => _trainingsError;

  Map<DateTime, List<AvailabilitySlot>> get availabilityMap => _availabilityMap;
  bool get availabilityLoading => _availabilityLoading;
  String? get availabilityError => _availabilityError;

  List<Location> get locations => _locations;

  Training? get nextTraining {
    final now = DateTime.now();
    final upcoming = _trainings
        .where((t) =>
            !t.isCancelled &&
            t.startTime != null &&
            t.startTime!.isAfter(now))
        .toList();
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.startTime!.compareTo(b.startTime!));
    return upcoming.first;
  }

  Future<void> fetchAboutUs() async {
    _aboutUsLoading = true;
    _aboutUsError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConfig.aboutUs);
      _aboutUsInfo = AboutUsInfo.fromJson(response);
    } on ApiException catch (e) {
      _aboutUsError = e.message;
    } catch (e) {
      _aboutUsError = 'Failed to load studio info';
    } finally {
      _aboutUsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchClients() async {
    _clientsLoading = true;
    _clientsError = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConfig.client);
      if (response is List) {
        _clients = response
            .map((e) => Client.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          _clients = data
              .map((e) => Client.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } else {
        _clients = [];
      }
    } on ApiException catch (e) {
      _clientsError = e.message;
    } catch (e) {
      _clientsError = 'Failed to load clients';
    } finally {
      _clientsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchTrainings(int trainerId,
      {DateTime? from, DateTime? to}) async {
    _trainingsLoading = true;
    _trainingsError = null;
    notifyListeners();

    final dateFrom = from ?? DateTime.now().subtract(const Duration(days: 30));
    final dateTo = to ?? DateTime.now().add(const Duration(days: 90));
    final fmt = DateFormat('yyyy-MM-dd');

    try {
      final response = await _apiService.get(ApiConfig.training, queryParams: {
        'trainer_id': trainerId.toString(),
        'date_from': fmt.format(dateFrom),
        'date_to': fmt.format(dateTo),
      });

      if (response is List) {
        _trainings = response
            .map((e) => Training.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          _trainings = data
              .map((e) => Training.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } else {
        _trainings = [];
      }
      // Sort by start time
      _trainings.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });
    } on ApiException catch (e) {
      _trainingsError = e.message;
    } catch (e) {
      _trainingsError = 'Failed to load trainings';
    } finally {
      _trainingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAvailability(int trainerId, int locationId,
      {DateTime? from, DateTime? to}) async {
    _availabilityLoading = true;
    _availabilityError = null;
    notifyListeners();

    final dateFrom = from ?? DateTime.now();
    final dateTo = to ??
        DateTime(DateTime.now().year, DateTime.now().month + 2, 1)
            .subtract(const Duration(days: 1));
    final fmt = DateFormat('yyyy-MM-dd');

    try {
      final response =
          await _apiService.get(ApiConfig.availability, queryParams: {
        'trainers[]': trainerId.toString(),
        'location_id': locationId.toString(),
        'from': fmt.format(dateFrom),
        'to': fmt.format(dateTo),
      });

      _availabilityMap = {};
      List<dynamic> slots = [];

      if (response is List) {
        slots = response;
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) slots = data;
      }

      for (final item in slots) {
        final slot = AvailabilitySlot.fromJson(item as Map<String, dynamic>);
        final slotDate = slot.slotDate;
        if (slotDate != null) {
          _availabilityMap.putIfAbsent(slotDate, () => []).add(slot);
        }
      }
    } on ApiException catch (e) {
      _availabilityError = e.message;
    } catch (e) {
      _availabilityError = 'Failed to load availability';
    } finally {
      _availabilityLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLocations() async {
    try {
      final response = await _apiService.get(ApiConfig.locationList);
      if (response is List) {
        _locations = response
            .map((e) => Location.fromJson(e as Map<String, dynamic>))
            .toList();
      } else if (response is Map && response.containsKey('data')) {
        final data = response['data'];
        if (data is List) {
          _locations = data
              .map((e) => Location.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      notifyListeners();
    } catch (_) {
      // Silently fail locations fetch
    }
  }

  Future<bool> cancelTraining(int trainingId) async {
    try {
      await _apiService.post(ApiConfig.cancelTraining,
          body: {'training_id': trainingId});
      // Update local state
      final index = _trainings.indexWhere((t) => t.id == trainingId);
      if (index != -1) {
        final t = _trainings[index];
        _trainings[index] = Training(
          id: t.id,
          title: t.title,
          startTime: t.startTime,
          endTime: t.endTime,
          date: t.date,
          timeFrom: t.timeFrom,
          timeTo: t.timeTo,
          clientId: t.clientId,
          clientName: t.clientName,
          trainerId: t.trainerId,
          trainerName: t.trainerName,
          locationId: t.locationId,
          locationName: t.locationName,
          trainingType: t.trainingType,
          status: 'cancelled',
          notes: t.notes,
          isCancelled: true,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  void clearAll() {
    _aboutUsInfo = null;
    _clients = [];
    _trainings = [];
    _availabilityMap = {};
    _locations = [];
    notifyListeners();
  }
}
