import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class AvailabilitySerialScreen extends StatefulWidget {
  final int trainerId;

  const AvailabilitySerialScreen({super.key, required this.trainerId});

  @override
  State<AvailabilitySerialScreen> createState() =>
      _AvailabilitySerialScreenState();
}

class _AvailabilitySerialScreenState extends State<AvailabilitySerialScreen> {
  final _apiService = ApiService();
  bool _saving = false;

  TimeOfDay _fromTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _toTime = const TimeOfDay(hour: 10, minute: 0);
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  final Set<int> _selectedDays = {1, 2, 3, 4, 5}; // Mon–Fri default

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDate(DateTime? d) =>
      d != null ? DateFormat('yyyy-MM-dd').format(d) : '';

  String _formatDateDisplay(DateTime? d) =>
      d != null ? DateFormat('dd.MM.yyyy').format(d) : 'Not set';

  Future<void> _pickTime(bool isFrom) async {
    final current = isFrom ? _fromTime : _toTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart
        ? (_rangeStart ?? DateTime.now())
        : (_rangeEnd ?? DateTime.now().add(const Duration(days: 30)));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _rangeStart = picked;
        } else {
          _rangeEnd = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (_rangeStart == null || _rangeEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }
    if (_rangeEnd!.isBefore(_rangeStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be after start date'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _apiService.postForm(ApiConfig.availabilitySerial, body: {
        'trainer_id': widget.trainerId.toString(),
        'from': _formatTime(_fromTime),
        'to': _formatTime(_toTime),
        'rStart': _formatDate(_rangeStart),
        'rEnd': _formatDate(_rangeEnd),
        'days': _selectedDays.join(','),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serial availability created successfully'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Serial Availability'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_outlined, size: 18, color: Colors.white),
            label: Text(_saving ? 'Saving…' : 'Save',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildCard('Time Slot', [
              _buildTimePicker('From', _fromTime, () => _pickTime(true)),
              const SizedBox(height: 10),
              _buildTimePicker('To', _toTime, () => _pickTime(false)),
            ]),
            const SizedBox(height: 16),
            _buildCard('Date Range', [
              _buildDatePicker('Start Date', _rangeStart, () => _pickDate(true)),
              const SizedBox(height: 10),
              _buildDatePicker('End Date', _rangeEnd, () => _pickDate(false)),
            ]),
            const SizedBox(height: 16),
            _buildCard('Days of Week', [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final selected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selectedDays.remove(day);
                      } else {
                        _selectedDays.add(day);
                      }
                    }),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _dayLabels[i],
                          style: TextStyle(
                            color: selected ? Colors.white : AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ]),
            const SizedBox(height: 24),
            _buildSummary(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.event_repeat),
                label: Text(_saving ? 'Creating…' : 'Create Serial Availability'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
          const Divider(color: AppColors.border, height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay time, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.muted, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const Spacer(),
            Text(_formatTime(time),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: AppColors.muted, size: 18),
            const SizedBox(width: 10),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const Spacer(),
            Text(_formatDateDisplay(date),
                style: TextStyle(
                    color: date != null ? Colors.white : AppColors.muted,
                    fontSize: 14,
                    fontWeight: date != null ? FontWeight.w600 : FontWeight.normal)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_rangeStart == null || _rangeEnd == null || _selectedDays.isEmpty) {
      return const SizedBox.shrink();
    }
    final days = _selectedDays.toList()..sort();
    final dayNames = days.map((d) => _dayLabels[d - 1]).join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Summary',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '${_formatTime(_fromTime)} – ${_formatTime(_toTime)}\n'
            '${_formatDateDisplay(_rangeStart)} → ${_formatDateDisplay(_rangeEnd)}\n'
            'Days: $dayNames',
            style: const TextStyle(color: AppColors.text, fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}
