import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trainer_provider.dart';
import '../config/app_colors.dart';

/// Einzelnes Zeitfenster anlegen — Ergänzung zur Serienverfügbarkeit
/// für spontane Zusatztermine.
///
/// Wird der Dialog mit einem `day` geöffnet (Kalender), steht das Datum
/// fest; ohne `day` (Profil) wählt man es im Dialog selbst.
/// Rückgabe: true = angelegt, false = fehlgeschlagen, null = abgebrochen.
Future<bool?> showSingleSlotDialog({
  required BuildContext context,
  required int trainerId,
  DateTime? day,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _SingleSlotDialog(trainerId: trainerId, day: day),
  );
}

class _SingleSlotDialog extends StatefulWidget {
  const _SingleSlotDialog({required this.trainerId, this.day});

  final int trainerId;
  final DateTime? day;

  @override
  State<_SingleSlotDialog> createState() => _SingleSlotDialogState();
}

class _SingleSlotDialogState extends State<_SingleSlotDialog> {
  late DateTime _date = widget.day ?? DateTime.now();
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 10, minute: 0);
  bool _saving = false;

  /// Datum ist nur wählbar, wenn der Aufrufer keins vorgibt.
  bool get _datePickable => widget.day == null;

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  ThemeData _pickerTheme(BuildContext ctx) => Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          surface: AppColors.surface,
          onSurface: Colors.white,
        ),
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _from : _to,
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  Future<void> _save() async {
    final startMin = _from.hour * 60 + _from.minute;
    final endMin = _to.hour * 60 + _to.minute;
    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Endzeit muss nach der Startzeit liegen')),
      );
      return;
    }

    setState(() => _saving = true);
    final ok = await context.read<TrainerProvider>().createAvailability(
          trainerId: widget.trainerId,
          date: DateFormat('yyyy-MM-dd').format(_date),
          from: _fmt(_from),
          to: _fmt(_to),
        );
    if (mounted) Navigator.pop(context, ok);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text(
        'Zeitfenster hinzufügen',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_datePickable)
            _field(
              label: 'Datum',
              value: DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(_date),
              onTap: _saving ? null : _pickDate,
            )
          else
            Text(
              DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(_date),
              style: const TextStyle(color: AppColors.text, fontSize: 14),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _field(
                  label: 'Von',
                  value: _fmt(_from),
                  onTap: _saving ? null : () => _pickTime(isFrom: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  label: 'Bis',
                  value: _fmt(_to),
                  onTap: _saving ? null : () => _pickTime(isFrom: false),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, null),
          child: const Text('Abbrechen',
              style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: Text(
            _saving ? 'Speichern…' : 'Speichern',
            style: const TextStyle(color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
