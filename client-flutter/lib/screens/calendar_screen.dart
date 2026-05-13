import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment.dart';
import '../models/calendar_data.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';
import 'credits_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<AppointmentProvider>().fetchCalendar(auth.clientId!);
    }
  }

  List<Appointment> _getEventsForDay(DateTime day) {
    final calData = context.read<AppointmentProvider>().calendarData;
    if (calData == null) return [];
    return calData.appointments.where((a) {
      return a.startDate.year == day.year &&
          a.startDate.month == day.month &&
          a.startDate.day == day.day;
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }

  /// Check if a trainer has availability on a given day.
  List<AvailabilityInterval> _getAvailabilityForDay(DateTime day) {
    final calData = context.read<AppointmentProvider>().calendarData;
    if (calData == null) return [];
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return calData.availabilityIntervals
        .where((a) => a.date == dateStr)
        .toList();
  }

  // ── Booking dialog ──────────────────────────────────────────────────────────

  void _showBookingDialog() {
    final appt = context.read<AppointmentProvider>();
    final calData = appt.calendarData;

    // Fix 17: Show message if no data/trainers/types
    if (calData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kalenderdaten werden noch geladen…'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }
    if (calData.trainers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kein Trainer verfügbar.'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }
    if (calData.trainingTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Keine Trainingsarten verfügbar.'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    // Block booking in the past
    final bookingDay = _selectedDay ?? DateTime.now();
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final selectedDate = DateTime(bookingDay.year, bookingDay.month, bookingDay.day);
    if (selectedDate.isBefore(todayDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buchungen in der Vergangenheit sind nicht möglich.'),
          backgroundColor: AppColors.orange,
        ),
      );
      return;
    }

    // Credit check — redirect to credits screen if no credits
    if (calData.credits <= 0) {
      _showNoCreditsDialog();
      return;
    }

    String? selectedTrainerId = calData.defaultTrainerId;
    String? selectedTypeId = calData.defaultTypeId;
    String? selectedLocationId =
        calData.locations.isNotEmpty ? calData.locations.first.id : null;
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    bool isBooking = false;

    // Duration is always 60 minutes
    const int durationMin = 60;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Fix 14: Filter availability by trainer + type + location
          final dayAvail = _getAvailabilityForDay(bookingDay)
              .where((a) {
                if (selectedTrainerId != null &&
                    a.trainerId != selectedTrainerId) return false;
                if (selectedTypeId != null &&
                    a.trainingTypeId != null &&
                    a.trainingTypeId != selectedTypeId) return false;
                if (selectedLocationId != null &&
                    a.locationId != null &&
                    a.locationId != selectedLocationId) return false;
                return true;
              })
              .toList();

          // Check if selected time is within an availability slot
          bool isTimeValid() {
            if (dayAvail.isEmpty) return true; // allow if no avail defined
            final selMinutes = selectedTime.hour * 60 + selectedTime.minute;
            final selEnd = selMinutes + durationMin;
            for (final slot in dayAvail) {
              final fromParts = slot.from.split(':');
              final toParts = slot.to.split(':');
              if (fromParts.length < 2 || toParts.length < 2) continue;
              final fromMin = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
              final toMin = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);
              if (selMinutes >= fromMin && selEnd <= toMin) return true;
            }
            return false;
          }

          // Check for double booking (client's own appointments)
          bool hasConflict() {
            final selMinutes = selectedTime.hour * 60 + selectedTime.minute;
            final selEnd = selMinutes + durationMin;
            for (final a in calData.appointments) {
              if (a.status.toLowerCase() == 'cancelled') continue;
              if (a.startDate.year != bookingDay.year ||
                  a.startDate.month != bookingDay.month ||
                  a.startDate.day != bookingDay.day) continue;
              final apptStart = a.startDate.hour * 60 + a.startDate.minute;
              final apptEnd = apptStart + a.duration;
              if (selMinutes < apptEnd && selEnd > apptStart) return true;
            }
            return false;
          }

          // Check trainer conflict (with 30-min buffer for different locations)
          String? trainerConflictMsg() {
            if (selectedTrainerId == null) return null;
            final dateStr = DateFormat('yyyy-MM-dd').format(bookingDay);
            final selMinutes = selectedTime.hour * 60 + selectedTime.minute;
            final selEnd = selMinutes + durationMin;
            const bufferMin = 30;

            for (final b in calData.trainerBookings) {
              if (b.trainerId != selectedTrainerId) continue;
              if (b.date != dateStr) continue;
              if (b.status.toLowerCase() == 'cancelled') continue;

              final parts = b.starttime.split(':');
              if (parts.length < 2) continue;
              final bStart = int.parse(parts[0]) * 60 + int.parse(parts[1]);
              final bEnd = bStart + b.duration;

              // Same location → no buffer, different → 30 min buffer
              final sameLocation = selectedLocationId != null &&
                  b.locationId != null &&
                  b.locationId == selectedLocationId;
              final buffer = sameLocation ? 0 : bufferMin;

              if (selMinutes < bEnd + buffer && bStart < selEnd + buffer) {
                if (buffer > 0) {
                  return 'Trainer hat einen Termin an einem anderen Standort. '
                      '30 Min. Pufferzeit nötig.';
                }
                return 'Trainer ist zu dieser Zeit bereits gebucht.';
              }
            }
            return null;
          }

          final timeValid = isTimeValid();
          final conflict = hasConflict();
          final trainerConflict = trainerConflictMsg();

          return AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Termin buchen',
                style: TextStyle(color: AppColors.text)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Fix 10: Selected date prominent at top
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEEE, d. MMMM yyyy', 'de_DE')
                              .format(bookingDay),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Credits display
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: calData.credits > 0
                          ? AppColors.green.withAlpha(15)
                          : AppColors.red.withAlpha(15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: calData.credits > 0
                            ? AppColors.green.withAlpha(40)
                            : AppColors.red.withAlpha(40),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.toll_outlined,
                            color: calData.credits > 0
                                ? AppColors.green
                                : AppColors.red,
                            size: 16),
                        const SizedBox(width: 8),
                        Text(
                          '${calData.credits} Credit${calData.credits != 1 ? 's' : ''} verfügbar',
                          style: TextStyle(
                              color: calData.credits > 0
                                  ? AppColors.green
                                  : AppColors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Trainer dropdown
                  DropdownButtonFormField<String>(
                    value: selectedTrainerId,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(
                      labelText: 'Trainer',
                      labelStyle: TextStyle(color: AppColors.muted),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.border)),
                    ),
                    style: const TextStyle(color: AppColors.text),
                    items: calData.trainers
                        .map((t) => DropdownMenuItem(
                            value: t.id, child: Text(t.fullName)))
                        .toList(),
                    onChanged: isBooking
                        ? null
                        : (v) =>
                            setDialogState(() => selectedTrainerId = v),
                  ),
                  const SizedBox(height: 12),

                  // Type dropdown + duration info
                  DropdownButtonFormField<String>(
                    value: selectedTypeId,
                    dropdownColor: AppColors.surface2,
                    decoration: const InputDecoration(
                      labelText: 'Trainingsart',
                      labelStyle: TextStyle(color: AppColors.muted),
                      enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppColors.border)),
                    ),
                    style: const TextStyle(color: AppColors.text),
                    items: calData.trainingTypes
                        .map((t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name)))
                        .toList(),
                    onChanged: isBooking
                        ? null
                        : (v) =>
                            setDialogState(() => selectedTypeId = v),
                  ),
                  const SizedBox(height: 12),

                  // Location dropdown
                  if (calData.locations.isNotEmpty)
                    DropdownButtonFormField<String>(
                      value: selectedLocationId,
                      dropdownColor: AppColors.surface2,
                      decoration: const InputDecoration(
                        labelText: 'Standort',
                        labelStyle: TextStyle(color: AppColors.muted),
                        enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppColors.border)),
                      ),
                      style: const TextStyle(color: AppColors.text),
                      items: calData.locations
                          .map((l) => DropdownMenuItem(
                              value: l.id, child: Text(l.name)))
                          .toList(),
                      onChanged: isBooking
                          ? null
                          : (v) =>
                              setDialogState(() => selectedLocationId = v),
                    ),
                  const SizedBox(height: 16),

                  // Available slots info
                  if (dayAvail.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.green.withAlpha(40)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verfügbare Zeiten (antippen zum Auswählen):',
                            style: TextStyle(
                              color: AppColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: dayAvail
                                .map((a) => GestureDetector(
                                      onTap: isBooking
                                          ? null
                                          : () {
                                              // Tap on slot to auto-fill time
                                              final parts = a.from.split(':');
                                              if (parts.length >= 2) {
                                                setDialogState(() {
                                                  selectedTime = TimeOfDay(
                                                    hour: int.parse(parts[0]),
                                                    minute: int.parse(parts[1]),
                                                  );
                                                });
                                              }
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.green.withAlpha(25),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.green
                                                  .withAlpha(50)),
                                        ),
                                        child: Text(
                                          '${a.from} – ${a.to}',
                                          style: const TextStyle(
                                              color: AppColors.green,
                                              fontSize: 11),
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                  if (dayAvail.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.orange.withAlpha(15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.orange.withAlpha(40)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.orange, size: 16),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Keine Verfügbarkeit an diesem Tag hinterlegt',
                              style: TextStyle(
                                  color: AppColors.orange, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // Time picker
                  InkWell(
                    onTap: isBooking
                        ? null
                        : () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                              builder: (context, child) {
                                return MediaQuery(
                                  data: MediaQuery.of(context).copyWith(
                                      alwaysUse24HourFormat: true),
                                  child: child!,
                                );
                              },
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: !timeValid
                                ? AppColors.red
                                : conflict
                                    ? AppColors.orange
                                    : AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              color: !timeValid
                                  ? AppColors.red
                                  : AppColors.muted,
                              size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: AppColors.text, fontSize: 15),
                          ),
                          const Spacer(),
                          Text(
                            '$durationMin Min.',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fix 4: Time validation warning
                  if (!timeValid && dayAvail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.red, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Gewählte Zeit liegt außerhalb der Verfügbarkeit',
                              style: TextStyle(
                                  color: AppColors.red, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Double booking warning (client's own)
                  if (conflict)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.block,
                              color: AppColors.red, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Du hast bereits einen Termin zu dieser Zeit.',
                              style: TextStyle(
                                  color: AppColors.red, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Trainer conflict / buffer warning
                  if (trainerConflict != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: AppColors.orange, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              trainerConflict,
                              style: TextStyle(
                                  color: AppColors.orange, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isBooking ? null : () => Navigator.pop(ctx),
                child: const Text('Abbrechen',
                    style: TextStyle(color: AppColors.muted)),
              ),
              ElevatedButton(
                onPressed: isBooking ||
                        selectedTrainerId == null ||
                        selectedTypeId == null ||
                        conflict ||
                        trainerConflict != null
                    ? null
                    : () async {
                        // Fix 9: Confirmation dialog
                        final trainerName = calData.trainers
                            .where((t) => t.id == selectedTrainerId)
                            .firstOrNull
                            ?.fullName ?? 'Unbekannt';
                        final typeName = calData.trainingTypes
                            .where((t) => t.id == selectedTypeId)
                            .firstOrNull
                            ?.name ?? 'Unbekannt';
                        final timeStr =
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                        final endMinutes = selectedTime.hour * 60 +
                            selectedTime.minute +
                            durationMin;
                        final endStr =
                            '${(endMinutes ~/ 60).toString().padLeft(2, '0')}:${(endMinutes % 60).toString().padLeft(2, '0')}';

                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (confirmCtx) => AlertDialog(
                            backgroundColor: AppColors.surface,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            title: const Text('Buchung bestätigen',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEEE, d. MMMM yyyy', 'de_DE')
                                      .format(bookingDay),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _confirmRow('Uhrzeit', '$timeStr – $endStr'),
                                _confirmRow('Trainer', trainerName),
                                _confirmRow('Typ', typeName),
                                _confirmRow('Dauer', '60 Min.'),
                                _confirmRow('Credits', '1 Credit'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(confirmCtx, false),
                                child: const Text('Zurück',
                                    style:
                                        TextStyle(color: AppColors.muted)),
                              ),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(confirmCtx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(8)),
                                ),
                                child: const Text('Jetzt buchen'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed != true) return;

                        // Fix 8: Show loading in dialog
                        setDialogState(() => isBooking = true);

                        final auth = context.read<AuthProvider>();
                        final success = await appt.bookAppointment(
                          auth.clientId!,
                          trainerId: selectedTrainerId!,
                          trainingTypeId: selectedTypeId!,
                          date: DateFormat('yyyy-MM-dd').format(bookingDay),
                          starttime: timeStr,
                          locationId: selectedLocationId,
                          duration: durationMin,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Termin erfolgreich gebucht!'
                                  : appt.error ??
                                      'Buchung fehlgeschlagen'),
                              backgroundColor:
                                  success ? AppColors.green : AppColors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: isBooking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Buchen'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showNoCreditsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Keine Credits verfügbar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Du hast keine verfügbaren Credits mehr. '
          'Bitte kaufe neue Credits, um Termine buchen zu können.',
          style: TextStyle(color: AppColors.text, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schliessen',
                style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreditsScreen()),
              );
            },
            icon: const Icon(Icons.toll_outlined, size: 18),
            label: const Text('Credits kaufen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Appointment detail bottom sheet ─────────────────────────────────────────

  void _showAppointmentDetail(Appointment appt) {
    final isCancelled = appt.status.toLowerCase() == 'cancelled';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + Status
            Row(
              children: [
                Expanded(
                  child: Text(
                    appt.trainingTypeName.isNotEmpty
                        ? appt.trainingTypeName
                        : 'Training',
                    style: TextStyle(
                      color: isCancelled ? AppColors.muted : AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
                _statusBadge(appt.status),
              ],
            ),
            const SizedBox(height: 14),

            // Details
            _detailRow(Icons.calendar_today_outlined, 'Datum',
                DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(appt.startDate)),
            _detailRow(Icons.access_time_outlined, 'Uhrzeit',
                '${DateFormat('HH:mm').format(appt.startDate)} – ${DateFormat('HH:mm').format(appt.startDate.add(Duration(minutes: appt.duration)))} (${appt.duration} Min.)'),
            _detailRow(Icons.person_outline, 'Trainer', appt.trainerName),
            if (appt.locationName.isNotEmpty)
              _detailRow(
                  Icons.location_on_outlined, 'Ort', appt.locationName),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                // iCal download
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addToCalendar(appt),
                    icon: const Icon(Icons.calendar_month_outlined,
                        size: 18),
                    label: const Text('Kalender'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                // Cancel button (only for active/booked – not cancelled, attended, or missed)
                if (!isCancelled &&
                    appt.status.toLowerCase() != 'attended' &&
                    appt.status.toLowerCase() != 'missed') ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _cancelAppointment(appt);
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Absagen'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: AppColors.red),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          SizedBox(
            width: 65,
            child: Text(label,
                style:
                    const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(color: AppColors.text, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.toLowerCase();
    Color color;
    String label;
    if (s == 'cancelled') {
      color = AppColors.red;
      label = 'Abgesagt';
    } else if (s == 'attended') {
      color = AppColors.green;
      label = 'Absolviert';
    } else if (s == 'missed') {
      color = AppColors.orange;
      label = 'Verpasst';
    } else {
      color = AppColors.primary;
      label = 'Gebucht';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _addToCalendar(Appointment appt) async {
    final url = Uri.parse(
        '${ApiConfig.baseUrl}api/training/${appt.id}/ical');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalender-Download fehlgeschlagen.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelAppointment(Appointment appt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Termin absagen',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Möchtest du diesen Termin wirklich absagen?',
              style: TextStyle(color: AppColors.text),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.green.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.green.withAlpha(40)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.toll_outlined,
                      color: AppColors.green, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dein Credit wird automatisch zurückerstattet.',
                      style: TextStyle(
                          color: AppColors.green, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Nein', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, absagen',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading SnackBar during cancellation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Termin wird abgesagt…'),
          ],
        ),
        backgroundColor: AppColors.orange,
        duration: Duration(seconds: 10),
      ),
    );

    final auth = context.read<AuthProvider>();
    final provider = context.read<AppointmentProvider>();
    final success =
        await provider.cancelAppointment(auth.clientId!, appt.id);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Termin abgesagt – Credit wurde zurückerstattet.'
              : provider.error ?? 'Absage fehlgeschlagen'),
          backgroundColor: success ? AppColors.green : AppColors.red,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appt = context.watch<AppointmentProvider>();
    final events =
        _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];
    final dayAvail =
        _selectedDay != null ? _getAvailabilityForDay(_selectedDay!) : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: appt.calendarData != null
          ? FloatingActionButton(
              onPressed: _showBookingDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded, color: AppColors.white),
            )
          : null,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: appt.isLoading && appt.calendarData == null
              ? const LoadingIndicator(message: 'Lade Kalender...')
              : appt.error != null && appt.calendarData == null
                  ? ErrorView(message: appt.error!, onRetry: _loadData)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Calendar ──
                        SliverToBoxAdapter(
                          child: Container(
                            margin:
                                const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TableCalendar<Object>(
                              firstDay: appt.calendarData?.minimumDate ??
                                  DateTime.now()
                                      .subtract(const Duration(days: 30)),
                              lastDay: appt.calendarData?.maximumDate ??
                                  DateTime.now()
                                      .add(const Duration(days: 90)),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected:
                                  (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              onPageChanged: (focusedDay) {
                                _focusedDay = focusedDay;
                              },
                              eventLoader: (day) {
                                // Combined: appointments + availability
                                final appts = _getEventsForDay(day);
                                final avail =
                                    _getAvailabilityForDay(day);
                                return [...appts, ...avail];
                              },
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                markerDecoration: const BoxDecoration(
                                  color: AppColors.green,
                                  shape: BoxShape.circle,
                                ),
                                defaultTextStyle: const TextStyle(
                                    color: AppColors.text),
                                weekendTextStyle: const TextStyle(
                                    color: AppColors.muted),
                                outsideTextStyle: TextStyle(
                                    color:
                                        AppColors.muted.withOpacity(0.4)),
                                markerSize: 6,
                                markersMaxCount: 4,
                              ),
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(
                                  color: AppColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                leftChevronIcon: Icon(
                                    Icons.chevron_left_rounded,
                                    color: AppColors.muted),
                                rightChevronIcon: Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.muted),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12),
                                weekendStyle: TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 12),
                              ),
                              startingDayOfWeek:
                                  StartingDayOfWeek.monday,
                              locale: 'de_DE',
                              calendarBuilders: CalendarBuilders(
                                markerBuilder:
                                    (context, day, events) {
                                  final appts = events
                                      .whereType<Appointment>()
                                      .toList();
                                  final avails = events
                                      .whereType<
                                          AvailabilityInterval>()
                                      .toList();

                                  if (appts.isEmpty &&
                                      avails.isEmpty) return null;

                                  final booked = appts
                                      .where((a) =>
                                          a.status.toLowerCase() ==
                                              'booked' ||
                                          a.status.toLowerCase() ==
                                              'attended')
                                      .length;
                                  final cancelled = appts
                                      .where((a) =>
                                          a.status.toLowerCase() ==
                                          'cancelled')
                                      .length;
                                  final missed = appts
                                      .where((a) =>
                                          a.status.toLowerCase() ==
                                          'missed')
                                      .length;

                                  return Positioned(
                                    bottom: 2,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (avails.isNotEmpty)
                                          _markerDot(AppColors.green),
                                        if (booked > 0)
                                          _markerCountDot(
                                              AppColors.primary,
                                              booked),
                                        if (missed > 0)
                                          _markerDot(AppColors.orange),
                                        if (cancelled > 0)
                                          _markerDot(AppColors.red),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        // ── Day header ──
                        if (_selectedDay != null)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  16, 14, 16, 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                              'EEEE, d. MMMM', 'de_DE')
                                          .format(_selectedDay!),
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (dayAvail.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.green.withAlpha(20),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration:
                                                const BoxDecoration(
                                              color: AppColors.green,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${dayAvail.length} verfügbar',
                                            style: const TextStyle(
                                              color: AppColors.green,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // ── Events for selected day ──
                        SliverPadding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 6, 16, 80),
                          sliver: events.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius:
                                          BorderRadius.circular(14),
                                      border: Border.all(
                                          color: AppColors.border),
                                    ),
                                    child: Column(
                                      children: [
                                        const Icon(Icons.event_outlined,
                                            color: AppColors.muted, size: 28),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Keine Termine an diesem Tag',
                                          style: TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 14),
                                        ),
                                        if (dayAvail.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tippe + um einen Termin zu buchen',
                                            style: TextStyle(
                                                color: AppColors.primary
                                                    .withAlpha(180),
                                                fontSize: 12),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10),
                                      child: _CalendarEventCard(
                                        appointment:
                                            events[i] as Appointment,
                                        onTap: () =>
                                            _showAppointmentDetail(
                                                events[i]
                                                    as Appointment),
                                      ),
                                    ),
                                    childCount: events.length,
                                  ),
                                ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _markerDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _markerCountDot(Color color, int count) {
    if (count <= 1) return _markerDot(color);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      height: 10,
      constraints: const BoxConstraints(minWidth: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════

class _CalendarEventCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _CalendarEventCard({
    required this.appointment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusLower = appointment.status.toLowerCase();
    final isCancelled = statusLower == 'cancelled';
    final isAttended = statusLower == 'attended';
    final isMissed = statusLower == 'missed';

    Color accentColor;
    if (isCancelled) {
      accentColor = AppColors.red;
    } else if (isAttended) {
      accentColor = AppColors.green;
    } else if (isMissed) {
      accentColor = AppColors.orange;
    } else {
      accentColor = AppColors.primary;
    }

    final timeStr = DateFormat('HH:mm').format(appointment.startDate);
    final endTime = appointment.startDate.add(Duration(minutes: appointment.duration));
    final endTimeStr = DateFormat('HH:mm').format(endTime);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withAlpha(40)),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.trainingTypeName.isNotEmpty
                        ? appointment.trainingTypeName
                        : 'Training',
                    style: TextStyle(
                      color: isCancelled ? AppColors.muted : AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      decoration:
                          isCancelled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        '$timeStr – $endTimeStr (${appointment.duration} Min.)',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          appointment.trainerName,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (appointment.locationName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          appointment.locationName,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isCancelled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Abgesagt',
                    style: TextStyle(color: AppColors.red, fontSize: 11)),
              )
            else if (isMissed)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Verpasst',
                    style: TextStyle(color: AppColors.orange, fontSize: 11)),
              )
            else
              const Icon(Icons.chevron_right,
                  color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
