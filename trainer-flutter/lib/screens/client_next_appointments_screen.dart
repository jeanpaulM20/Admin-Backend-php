import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class _Appointment {
  final int? id;
  final String? date;
  final String? timeFrom;
  final String? timeTo;
  final String? locationName;
  final String? status;
  final bool isCancelled;
  final DateTime? startTime;

  const _Appointment({
    this.id,
    this.date,
    this.timeFrom,
    this.timeTo,
    this.locationName,
    this.status,
    this.isCancelled = false,
    this.startTime,
  });

  factory _Appointment.fromJson(Map<String, dynamic> json) {
    DateTime? start;
    final rawDate = json['date']?.toString();
    final rawTime = json['time_from']?.toString() ?? json['timeFrom']?.toString();
    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        final combined = rawTime != null && rawTime.isNotEmpty
            ? '$rawDate $rawTime'
            : rawDate;
        start = DateTime.tryParse(combined) ??
            DateFormat('yyyy-MM-dd').tryParse(rawDate);
      } catch (_) {}
    }

    return _Appointment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      date: rawDate,
      timeFrom: rawTime,
      timeTo: json['time_to']?.toString() ?? json['timeTo']?.toString(),
      locationName: json['location_name']?.toString() ?? json['locationName']?.toString(),
      status: json['status']?.toString(),
      isCancelled: json['status']?.toString() == 'cancelled' || json['is_cancelled'] == true,
      startTime: start,
    );
  }

  String get displayDate {
    if (startTime != null) return DateFormat('EEE, dd.MM.yyyy').format(startTime!);
    return date ?? '';
  }

  String get displayTime {
    if (timeFrom != null && timeTo != null) return '$timeFrom – $timeTo';
    if (timeFrom != null) return timeFrom!;
    return '';
  }
}

class ClientNextAppointmentsScreen extends StatefulWidget {
  final Client client;

  const ClientNextAppointmentsScreen({super.key, required this.client});

  @override
  State<ClientNextAppointmentsScreen> createState() =>
      _ClientNextAppointmentsScreenState();
}

class _ClientNextAppointmentsScreenState
    extends State<ClientNextAppointmentsScreen> {
  final _apiService = ApiService();
  bool _loading = true;
  String? _error;
  List<_Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd');
      final resp = await _apiService.get(
        ApiConfig.training,
        queryParams: {
          'client_id': widget.client.id.toString(),
          'date': fmt.format(now),
          'time': '00:00:00',
        },
      );
      List<dynamic> list = [];
      if (resp is List) {
        list = resp;
      } else if (resp is Map && resp['data'] is List) {
        list = resp['data'] as List;
      }
      _appointments = list
          .map((e) => _Appointment.fromJson(e as Map<String, dynamic>))
          .where((a) => !a.isCancelled)
          .toList();
      _appointments.sort((a, b) {
        if (a.startTime == null && b.startTime == null) return 0;
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load appointments';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancel(_Appointment appointment) async {
    if (appointment.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Cancel Appointment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Cancel appointment on ${appointment.displayDate}?',
          style: const TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _apiService.post('${ApiConfig.training}/${appointment.id}/cancel');
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Next Appointments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _buildError()
              : _appointments.isEmpty
                  ? _buildEmpty()
                  : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.primary, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, color: AppColors.muted, size: 56),
          SizedBox(height: 16),
          Text('No upcoming appointments',
              style: TextStyle(color: AppColors.muted, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        itemCount: _appointments.length,
        itemBuilder: (_, i) {
          final apt = _appointments[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(apt.displayDate,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15)),
                          if (apt.displayTime.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(apt.displayTime,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          ],
                          if (apt.locationName != null) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined,
                                    size: 13, color: AppColors.muted),
                                const SizedBox(width: 3),
                                Text(apt.locationName!,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _cancel(apt),
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: const Text('Cancel Appointment', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary, width: 0.8),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
