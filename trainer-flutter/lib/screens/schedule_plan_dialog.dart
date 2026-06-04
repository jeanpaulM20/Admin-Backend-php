import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/training_plan.dart';
import '../models/availability.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

/// Dialog for the trainer to schedule a specific training plan
/// into the client's calendar at a chosen date & time.
class SchedulePlanDialog extends StatefulWidget {
  final int trainerId;
  final int clientId;
  final String clientName;
  final TrainingPlan plan;
  final List<Location> locations;

  const SchedulePlanDialog({
    super.key,
    required this.trainerId,
    required this.clientId,
    required this.clientName,
    required this.plan,
    required this.locations,
  });

  static Future<bool?> show(
    BuildContext context, {
    required int trainerId,
    required int clientId,
    required String clientName,
    required TrainingPlan plan,
    required List<Location> locations,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SchedulePlanDialog(
        trainerId: trainerId,
        clientId: clientId,
        clientName: clientName,
        plan: plan,
        locations: locations,
      ),
    );
  }

  @override
  State<SchedulePlanDialog> createState() => _SchedulePlanDialogState();
}

class _SchedulePlanDialogState extends State<SchedulePlanDialog> {
  final _api = ApiService();
  bool _saving = false;
  String? _error;

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) setState(() => _selectedTime = time);
  }

  Future<void> _schedule() async {
    if (widget.plan.id == null) {
      setState(() => _error = 'Trainingsplan hat keine gültige ID');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      // Online coaching workout — no location, no in-person training type
      await _api.post('${ApiConfig.training}/schedule-plan', body: {
        'client_id': widget.clientId,
        'training_plan_id': widget.plan.id,
        'date': dateStr,
        'starttime': timeStr,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Workout "${widget.plan.name ?? 'Trainingsplan'}" für ${widget.clientName} geplant'),
        backgroundColor: AppColors.green,
      ));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Planung fehlgeschlagen');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final planName = widget.plan.name ?? 'Trainingsplan #${widget.plan.id}';

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withAlpha(77),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.event_available, color: AppColors.primary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Workout planen',
                          style: GoogleFonts.montserrat(
                              color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(planName + '  →  ' + widget.clientName,
                          style: GoogleFonts.openSans(
                              color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text('Online Coaching — kein Standort nötig',
                          style: GoogleFonts.openSans(
                              color: AppColors.primary.withAlpha(178),
                              fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.red.withAlpha(31),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                    style: GoogleFonts.openSans(color: AppColors.red, fontSize: 13))),
              ]),
            ),
          if (_error != null) const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: _pickerTile(
                  icon: Icons.calendar_today,
                  label: 'Datum',
                  value: DateFormat('dd.MM.yyyy').format(_selectedDate),
                  onTap: _pickDate,
                )),
                const SizedBox(width: 10),
                Expanded(child: _pickerTile(
                  icon: Icons.access_time,
                  label: 'Uhrzeit',
                  value: '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  onTap: _pickTime,
                )),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _schedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Workout planen',
                        style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.openSans(
                  color: AppColors.muted, fontSize: 10, fontWeight: FontWeight.w600)),
              Text(value, style: GoogleFonts.montserrat(
                  color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ]),
      ),
    );
  }
}
