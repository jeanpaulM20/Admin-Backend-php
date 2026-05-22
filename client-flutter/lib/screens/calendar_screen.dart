// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/app_colors.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/preference_provider.dart';
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
  bool _booking = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await Future.wait([
        context.read<AppointmentProvider>().fetchCalendar(auth.clientId!),
        context.read<PreferenceProvider>().load(auth.clientId!),
      ]);
      if (mounted) setState(() {});
    }
  }

  // ── Data helpers ─────────────────────────────────────────────────────────────

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

  List<AvailabilityInterval> _getAvailabilityForDay(DateTime day) {
    final calData = context.read<AppointmentProvider>().calendarData;
    if (calData == null) return [];
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return calData.availabilityIntervals
        .where((a) => a.date == dateStr)
        .toList();
  }

  // ── Shared helpers (single source of truth for buffer/time logic) ──────────

  /// Safe time parsing — returns null instead of throwing on malformed strings.
  int? _parseTimeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Map<String, int> _buildLocationBuffers(CalendarData calData) {
    return { for (final loc in calData.locations) loc.id: loc.bufferMinutes };
  }

  /// Single source of truth: is [trainerId] free at [startMin]–[endMin]
  /// for [locationId], considering buffer times from other bookings?
  bool _isTrainerFree({
    required String trainerId,
    required String? locationId,
    required int startMin,
    required int endMin,
    required String dateStr,
    required CalendarData calData,
    required Map<String, int> locationBuffers,
  }) {
    for (final b in calData.trainerBookings) {
      if (b.trainerId != trainerId) continue;
      if (b.date != dateStr) continue;
      if (b.status.toLowerCase() == 'cancelled') continue;
      final bStart = _parseTimeToMinutes(b.starttime);
      if (bStart == null) continue;
      final bEnd = bStart + b.duration;
      final sameLocation = locationId != null &&
          b.locationId != null &&
          b.locationId == locationId;
      int buffer = 0;
      if (!sameLocation) {
        final reqBuffer =
            locationId != null ? (locationBuffers[locationId] ?? 30) : 30;
        final existBuffer =
            b.locationId != null ? (locationBuffers[b.locationId!] ?? 30) : 30;
        buffer = reqBuffer > existBuffer ? reqBuffer : existBuffer;
      }
      if (startMin < bEnd + buffer && bStart < endMin + buffer) {
        return false;
      }
    }
    return true;
  }

  /// Generate 30-minute time slots for the selected day.
  /// Shows all times where at least one trainer+location combo is free.
  List<_TimeSlot> _generateSlots(DateTime day, CalendarData calData) {
    const int slotDuration = 60;
    const int slotStep = 30;
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final now = DateTime.now();
    final locationBuffers = _buildLocationBuffers(calData);

    // All availability for this day
    final dayAvail = calData.availabilityIntervals
        .where((a) => a.date == dateStr)
        .toList();
    if (dayAvail.isEmpty) return [];

    // Collect all possible 30-min start minutes (safe parsing)
    final Set<int> allMinutes = {};
    for (final a in dayAvail) {
      final fromMin = _parseTimeToMinutes(a.from);
      final toMin = _parseTimeToMinutes(a.to);
      if (fromMin == null || toMin == null) continue;
      for (int m = fromMin; m + slotDuration <= toMin; m += slotStep) {
        allMinutes.add(m);
      }
    }
    if (allMinutes.isEmpty) return [];

    final sorted = allMinutes.toList()..sort();
    final slots = <_TimeSlot>[];

    for (final startMin in sorted) {
      final endMin = startMin + slotDuration;

      // 12h advance check
      final slotDateTime = DateTime(day.year, day.month, day.day, startMin ~/ 60, startMin % 60);
      if (slotDateTime.difference(now).inMinutes / 60.0 < 12) continue;

      // Client double-booking check
      bool clientConflict = false;
      for (final a in calData.appointments) {
        if (a.status.toLowerCase() == 'cancelled') continue;
        if (a.startDate.year != day.year || a.startDate.month != day.month || a.startDate.day != day.day) continue;
        final apptStart = a.startDate.hour * 60 + a.startDate.minute;
        final apptEnd = apptStart + a.duration;
        if (startMin < apptEnd && apptStart < endMin) {
          clientConflict = true;
          break;
        }
      }
      if (clientConflict) continue;

      // Check if ANY trainer+location combo is free at this time
      bool anyFree = false;
      for (final a in dayAvail) {
        final fromMin = _parseTimeToMinutes(a.from);
        final toMin = _parseTimeToMinutes(a.to);
        if (fromMin == null || toMin == null) continue;
        if (startMin < fromMin || endMin > toMin) continue;

        if (_isTrainerFree(
          trainerId: a.trainerId,
          locationId: a.locationId,
          startMin: startMin,
          endMin: endMin,
          dateStr: dateStr,
          calData: calData,
          locationBuffers: locationBuffers,
        )) {
          anyFree = true;
          break;
        }
      }
      if (!anyFree) continue;

      slots.add(_TimeSlot(
        startMin: startMin,
        timeStr: _minutesToTime(startMin),
        endTimeStr: _minutesToTime(endMin),
      ));
    }

    return slots;
  }

  /// Returns available (trainer, location) combos for a given time slot.
  List<_SlotOption> _getOptionsForSlot(_TimeSlot slot, DateTime day, CalendarData calData) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final startMin = slot.startMin;
    final endMin = startMin + 60;
    final locationBuffers = _buildLocationBuffers(calData);

    final options = <_SlotOption>[];
    final dayAvail = calData.availabilityIntervals.where((a) => a.date == dateStr).toList();

    for (final a in dayAvail) {
      final fromMin = _parseTimeToMinutes(a.from);
      final toMin = _parseTimeToMinutes(a.to);
      if (fromMin == null || toMin == null) continue;
      if (startMin < fromMin || endMin > toMin) continue;

      if (_isTrainerFree(
        trainerId: a.trainerId,
        locationId: a.locationId,
        startMin: startMin,
        endMin: endMin,
        dateStr: dateStr,
        calData: calData,
        locationBuffers: locationBuffers,
      )) {
        options.add(_SlotOption(
          trainerId: a.trainerId,
          locationId: a.locationId,
          trainingTypeId: a.trainingTypeId,
        ));
      }
    }

    // Deduplicate by trainer+location
    final seen = <String>{};
    return options.where((o) {
      final key = '${o.trainerId}:${o.locationId}';
      return seen.add(key);
    }).toList();
  }

  /// Check if a trainer is free at [startMin] for a given [chosenLocationId].
  /// Thin wrapper around [_isTrainerFree] for the booking sheet.
  bool _isTrainerFreeForLocation({
    required String trainerId,
    required String chosenLocationId,
    required int startMin,
    required String dateStr,
    required CalendarData calData,
  }) {
    return _isTrainerFree(
      trainerId: trainerId,
      locationId: chosenLocationId,
      startMin: startMin,
      endMin: startMin + 60,
      dateStr: dateStr,
      calData: calData,
      locationBuffers: _buildLocationBuffers(calData),
    );
  }

  String _minutesToTime(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  // ── Booking ─────────────────────────────────────────────────────────────────

  Future<void> _bookSlot(_TimeSlot slot) async {
    if (_booking) return;
    _booking = true;
    try {
    final appt = context.read<AppointmentProvider>();
    final calData = appt.calendarData;
    if (calData == null) return;

    if (calData.credits <= 0) {
      _showNoCreditsDialog();
      return;
    }

    final bookingDay = _selectedDay ?? DateTime.now();
    final options = _getOptionsForSlot(slot, bookingDay, calData);

    if (options.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Slot nicht mehr verfügbar.'), backgroundColor: AppColors.red),
        );
      }
      return;
    }

    // Show booking sheet with trainer/location selection
    final selection = await _showBookingSheet(slot, bookingDay, calData, options);
    if (selection == null || !mounted) return;

    // Execute booking
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Termin wird gebucht...'),
        ]),
        backgroundColor: AppColors.primary,
        duration: Duration(seconds: 10),
      ),
    );

    final auth = context.read<AuthProvider>();
    final success = await appt.bookAppointment(
      auth.clientId!,
      trainerId: selection.trainerId,
      trainingTypeId: selection.trainingTypeId ?? calData.defaultTypeId ?? '',
      date: DateFormat('yyyy-MM-dd').format(bookingDay),
      starttime: slot.timeStr,
      locationId: selection.locationId,
      duration: 60,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (success) {
        context.read<PreferenceProvider>().savePreferences(auth.clientId!, {
          'trainer_id': selection.trainerId,
          'training_type_id': selection.trainingTypeId,
          'location_id': selection.locationId,
        }).catchError((_) {});
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? 'Termin erfolgreich gebucht!'
              : appt.error ?? 'Buchung fehlgeschlagen'),
          backgroundColor: success ? AppColors.green : AppColors.red,
        ),
      );
    }
    } finally {
      _booking = false;
    }
  }

  /// Bottom sheet with Trainer + Location dropdowns + confirm button.
  Future<_SlotSelection?> _showBookingSheet(
    _TimeSlot slot,
    DateTime day,
    CalendarData calData,
    List<_SlotOption> options,
  ) {
    final pref = context.read<PreferenceProvider>();
    final trainerIds = options.map((o) => o.trainerId).toSet().toList();
    final allLocationIds = calData.locations.map((l) => l.id).toList();
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    // Pre-select from preferences or single option
    String? initTrainer = trainerIds.contains(pref.trainerId)
        ? pref.trainerId
        : (trainerIds.length == 1 ? trainerIds.first : null);
    String? initLocation;
    if (allLocationIds.contains(pref.locationId)) {
      initLocation = pref.locationId;
    } else if (allLocationIds.length == 1) {
      initLocation = allLocationIds.first;
    }

    return showModalBottomSheet<_SlotSelection>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? selTrainer = initTrainer;
        String? selLocation = initLocation;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            // Filter locations by buffer — only show locations where trainer is actually free
            final availLocations = selTrainer != null
                ? allLocationIds.where((locId) => _isTrainerFreeForLocation(
                    trainerId: selTrainer!,
                    chosenLocationId: locId,
                    startMin: slot.startMin,
                    dateStr: dateStr,
                    calData: calData,
                  )).toList()
                : allLocationIds;

            // Reset location if not available with buffer — track for user notification
            final prevLocation = selLocation;
            if (selLocation != null && !availLocations.contains(selLocation)) {
              selLocation = availLocations.length == 1 ? availLocations.first : null;
            }
            final locationWasReset = prevLocation != null && prevLocation != selLocation;
            // Auto-select singles
            if (selTrainer == null && trainerIds.length == 1) selTrainer = trainerIds.first;
            if (selLocation == null && availLocations.length == 1) selLocation = availLocations.first;

            final canConfirm = selTrainer != null && selLocation != null;
            final trainerName = selTrainer != null
                ? (calData.trainers.where((t) => t.id == selTrainer).firstOrNull?.fullName ?? '')
                : '';
            final locationName = selLocation != null
                ? (calData.locations.where((l) => l.id == selLocation).firstOrNull?.name ?? '')
                : '';

            return Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),
                  const Text('Termin buchen',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('EEEE, d. MMMM', 'de_DE').format(day),
                      style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.access_time_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${slot.timeStr} – ${slot.endTimeStr} (60 Min.)',
                      style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ]),
                  const SizedBox(height: 20),

                  // Trainer dropdown
                  const Text('Trainer', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selTrainer,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        hint: const Text('Trainer wählen', style: TextStyle(color: AppColors.muted)),
                        style: const TextStyle(color: AppColors.text, fontSize: 14),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                        items: trainerIds.map((id) {
                          final t = calData.trainers.where((t) => t.id == id).firstOrNull;
                          return DropdownMenuItem(value: id, child: Text(t?.fullName ?? id));
                        }).toList(),
                        onChanged: (v) => setModalState(() {
                          selTrainer = v;
                          // Location stays — client can pick any location independently
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Location dropdown
                  const Text('Standort', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: availLocations.contains(selLocation) ? selLocation : null,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        hint: const Text('Standort wählen', style: TextStyle(color: AppColors.muted)),
                        style: const TextStyle(color: AppColors.text, fontSize: 14),
                        icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
                        items: availLocations.map((id) {
                          final l = calData.locations.where((l) => l.id == id).firstOrNull;
                          return DropdownMenuItem(value: id, child: Text(l?.name ?? id));
                        }).toList(),
                        onChanged: (v) => setModalState(() => selLocation = v),
                      ),
                    ),
                  ),
                  if (locationWasReset)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(children: [
                        Icon(Icons.info_outline, size: 13, color: AppColors.orange),
                        SizedBox(width: 4),
                        Expanded(child: Text(
                          'Standort angepasst (Pufferzeit mit neuem Trainer)',
                          style: TextStyle(color: AppColors.orange, fontSize: 11),
                        )),
                      ]),
                    ),
                  const SizedBox(height: 20),

                  // Summary when ready
                  if (canConfirm)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.green.withAlpha(10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.green.withAlpha(30)),
                      ),
                      child: Column(children: [
                        _confirmRow('Trainer', trainerName),
                        _confirmRow('Ort', locationName),
                        _confirmRow('Dauer', '60 Min.'),
                        _confirmRow('Credits', '1 Credit'),
                      ]),
                    ),

                  // Buttons
                  Row(children: [
                    Expanded(child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: ElevatedButton(
                      onPressed: canConfirm
                          ? () {
                              // Get training type from trainer's availability (location is client choice)
                              final trainerOpt = options.where((o) =>
                                  o.trainerId == selTrainer).firstOrNull;
                              Navigator.pop(ctx, _SlotSelection(
                                trainerId: selTrainer!,
                                locationId: selLocation!,
                                trainingTypeId: trainerOpt?.trainingTypeId,
                              ));
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.muted.withAlpha(40),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Jetzt buchen', style: TextStyle(fontWeight: FontWeight.w700)),
                    )),
                  ]),
                ],
              ),
            );
          },
        );
      },
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
            child: const Text('Schließen', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditsScreen()));
            },
            icon: const Icon(Icons.toll_outlined, size: 18),
            label: const Text('Credits kaufen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ── Cancel appointment ─────────────────────────────────────────────────────

  Future<void> _cancelAppointment(Appointment appt) async {
    if (_cancelling) return;
    final hoursUntil = appt.startDate.difference(DateTime.now()).inMinutes / 60.0;
    final isLateCancellation = hoursUntil < 12;

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
            const Text('Möchtest du diesen Termin wirklich absagen?',
                style: TextStyle(color: AppColors.text)),
            const SizedBox(height: 10),
            if (isLateCancellation)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.red.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.red.withAlpha(40)),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.red, size: 14),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    'Verspätete Absage (weniger als 12 Stunden). Dein Credit wird nicht zurückerstattet.',
                    style: TextStyle(color: AppColors.red, fontSize: 12),
                  )),
                ]),
              )
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.green.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.green.withAlpha(40)),
                ),
                child: const Row(children: [
                  Icon(Icons.toll_outlined, color: AppColors.green, size: 14),
                  SizedBox(width: 6),
                  Expanded(child: Text(
                    'Dein Credit wird automatisch zurückerstattet.',
                    style: TextStyle(color: AppColors.green, fontSize: 12),
                  )),
                ]),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Nein', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ja, absagen', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _cancelling = true;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Termin wird abgesagt...'),
          ]),
          backgroundColor: AppColors.orange,
          duration: Duration(seconds: 10),
        ),
      );

      final auth = context.read<AuthProvider>();
      final provider = context.read<AppointmentProvider>();
      final result = await provider.cancelAppointment(auth.clientId!, appt.id);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (result != null) {
          // Use backend's authoritative decision (not local time calculation)
          final creditRefunded = result['creditRefunded'] == true;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(creditRefunded
                  ? 'Termin abgesagt – Credit wurde zurückerstattet.'
                  : 'Termin abgesagt – Credit wurde nicht zurückerstattet.'),
              backgroundColor: creditRefunded ? AppColors.green : AppColors.orange,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Absage fehlgeschlagen'),
              backgroundColor: AppColors.red,
            ),
          );
        }
      }
    } finally {
      _cancelling = false;
    }
  }

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
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Text(
                appt.trainingTypeName.isNotEmpty ? appt.trainingTypeName : 'Training',
                style: TextStyle(
                  color: isCancelled ? AppColors.muted : AppColors.text,
                  fontSize: 18, fontWeight: FontWeight.w700,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              )),
              _statusBadge(appt.status),
            ]),
            const SizedBox(height: 14),
            _detailRow(Icons.calendar_today_outlined, 'Datum',
                DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(appt.startDate)),
            _detailRow(Icons.access_time_outlined, 'Uhrzeit',
                '${DateFormat('HH:mm').format(appt.startDate)} – ${DateFormat('HH:mm').format(appt.startDate.add(Duration(minutes: appt.duration)))} (${appt.duration} Min.)'),
            _detailRow(Icons.person_outline, 'Trainer', appt.trainerName),
            if (appt.locationName.isNotEmpty)
              _detailRow(Icons.location_on_outlined, 'Ort', appt.locationName),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _addToCalendar(appt),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('Kalender'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              )),
              if (!isCancelled &&
                  appt.status.toLowerCase() != 'attended' &&
                  appt.status.toLowerCase() != 'missed') ...[
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _cancelAppointment(appt); },
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Absagen'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                )),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 8),
        SizedBox(width: 65, child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: AppColors.text, fontSize: 14))),
      ]),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.toLowerCase();
    Color color;
    String label;
    if (s == 'cancelled') { color = AppColors.red; label = 'Abgesagt'; }
    else if (s == 'attended') { color = AppColors.green; label = 'Absolviert'; }
    else if (s == 'missed') { color = AppColors.orange; label = 'Verpasst'; }
    else { color = AppColors.primary; label = 'Gebucht'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _addToCalendar(Appointment appt) async {
    final url = '${ApiConfig.baseUrl}api/training/${appt.id}/ical';
    try {
      // Use an anchor element to force .ics file download in web browsers
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'training-${appt.id}.ics')
        ..style.display = 'none';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      debugPrint('iCal download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kalender-Download fehlgeschlagen.'), backgroundColor: AppColors.red),
        );
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final appt = context.watch<AppointmentProvider>();
    final calData = appt.calendarData;
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <Appointment>[];
    final dayAvail = _selectedDay != null ? _getAvailabilityForDay(_selectedDay!) : <AvailabilityInterval>[];
    final slots = (_selectedDay != null && calData != null)
        ? _generateSlots(_selectedDay!, calData)
        : <_TimeSlot>[];
    final availableSlots = slots.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: appt.isLoading && calData == null
              ? const LoadingIndicator(message: 'Lade Kalender...')
              : appt.error != null && calData == null
                  ? ErrorView(message: appt.error!, onRetry: _loadData)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // ── Calendar ──
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TableCalendar<Object>(
                              firstDay: calData?.minimumDate ?? DateTime.now().subtract(const Duration(days: 30)),
                              lastDay: calData?.maximumDate ?? DateTime.now().add(const Duration(days: 90)),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                              },
                              onPageChanged: (focusedDay) { _focusedDay = focusedDay; },
                              eventLoader: (day) {
                                final appts = _getEventsForDay(day);
                                final avail = _getAvailabilityForDay(day);
                                return [...appts, ...avail];
                              },
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(77),
                                  shape: BoxShape.circle,
                                ),
                                selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                markerDecoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                                defaultTextStyle: const TextStyle(color: AppColors.text),
                                weekendTextStyle: const TextStyle(color: AppColors.muted),
                                outsideTextStyle: TextStyle(color: AppColors.muted.withAlpha(102)),
                                markerSize: 6,
                                markersMaxCount: 4,
                              ),
                              headerStyle: const HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                titleTextStyle: TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700),
                                leftChevronIcon: Icon(Icons.chevron_left_rounded, color: AppColors.muted),
                                rightChevronIcon: Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                              ),
                              daysOfWeekStyle: const DaysOfWeekStyle(
                                weekdayStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                                weekendStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                              ),
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              locale: 'de_DE',
                              calendarBuilders: CalendarBuilders(
                                markerBuilder: (context, day, events) {
                                  final appts = events.whereType<Appointment>().toList();
                                  final avails = events.whereType<AvailabilityInterval>().toList();
                                  if (appts.isEmpty && avails.isEmpty) return null;

                                  final booked = appts.where((a) =>
                                      a.status.toLowerCase() == 'booked' || a.status.toLowerCase() == 'attended').length;
                                  final cancelled = appts.where((a) => a.status.toLowerCase() == 'cancelled').length;
                                  final missed = appts.where((a) => a.status.toLowerCase() == 'missed').length;
                                  // Green dot only for today/future — past availability is not bookable
                                  final today = DateTime.now();
                                  final isFutureDay = day.isAfter(today.subtract(const Duration(days: 1)));

                                  return Positioned(
                                    bottom: 2,
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (avails.isNotEmpty && isFutureDay) _markerDot(AppColors.green),
                                      if (booked > 0) _markerCountDot(AppColors.primary, booked),
                                      if (missed > 0) _markerDot(AppColors.orange),
                                      if (cancelled > 0) _markerDot(AppColors.red),
                                    ]),
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
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              child: Row(children: [
                                Expanded(child: Text(
                                  DateFormat('EEEE, d. MMMM', 'de_DE').format(_selectedDay!),
                                  style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600),
                                )),
                                if (availableSlots > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.green.withAlpha(20),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      Text('$availableSlots Slots frei', style: const TextStyle(color: AppColors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                                    ]),
                                  ),
                                if (calData != null && calData.credits > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withAlpha(20),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${calData.credits} Cr.',
                                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ),
                              ]),
                            ),
                          ),

                        // ── Existing appointments for day ──
                        if (events.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (ctx, i) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _CalendarEventCard(
                                    appointment: events[i],
                                    onTap: () => _showAppointmentDetail(events[i]),
                                  ),
                                ),
                                childCount: events.length,
                              ),
                            ),
                          ),

                        // ── Slot Grid ──
                        if (slots.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            sliver: SliverToBoxAdapter(
                              child: _SlotGrid(
                                slots: slots,
                                onSlotTap: _bookSlot,
                              ),
                            ),
                          )
                        else if (_selectedDay != null && dayAvail.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Column(children: [
                                  Icon(Icons.event_busy_outlined, color: AppColors.muted, size: 28),
                                  SizedBox(height: 8),
                                  Text('Keine Verfügbarkeit an diesem Tag.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 14)),
                                ]),
                              ),
                            ),
                          )
                        else if (_selectedDay != null && slots.isEmpty && dayAvail.isNotEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Column(children: [
                                  Icon(Icons.event_busy_outlined, color: AppColors.orange, size: 28),
                                  SizedBox(height: 8),
                                  Text('Keine Termine an diesem Tag verfügbar.',
                                      style: TextStyle(color: AppColors.orange, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text('Bitte einen anderen Tag wählen.',
                                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                                ]),
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
      width: 6, height: 6,
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
      child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold, height: 1)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Slot Grid Widget
// ═══════════════════════════════════════════════════════════════════════════════

class _TimeSlot {
  final int startMin;
  final String timeStr;
  final String endTimeStr;

  const _TimeSlot({
    required this.startMin,
    required this.timeStr,
    required this.endTimeStr,
  });
}

class _SlotOption {
  final String trainerId;
  final String? locationId;
  final String? trainingTypeId;

  const _SlotOption({
    required this.trainerId,
    this.locationId,
    this.trainingTypeId,
  });
}

class _SlotSelection {
  final String trainerId;
  final String locationId;
  final String? trainingTypeId;

  const _SlotSelection({
    required this.trainerId,
    required this.locationId,
    this.trainingTypeId,
  });
}

class _SlotGrid extends StatelessWidget {
  final List<_TimeSlot> slots;
  final ValueChanged<_TimeSlot> onSlotTap;

  const _SlotGrid({required this.slots, required this.onSlotTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(children: [
              Icon(Icons.grid_view_rounded, size: 14, color: AppColors.muted),
              SizedBox(width: 6),
              Text('Verfügbare Slots', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: slots.map((slot) => _SlotTile(slot: slot, onTap: onSlotTap)).toList(),
            ),
          ),
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(children: [
              _legendDot(AppColors.green, 'Antippen zum Buchen'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: color, fontSize: 10)),
    ]);
  }
}

class _SlotTile extends StatelessWidget {
  final _TimeSlot slot;
  final ValueChanged<_TimeSlot> onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${slot.timeStr} – ${slot.endTimeStr}',
      child: GestureDetector(
        onTap: () => onTap(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.green.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.green.withAlpha(60)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slot.timeStr,
                style: const TextStyle(
                  color: AppColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                slot.endTimeStr,
                style: TextStyle(color: AppColors.green.withAlpha(150), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Calendar Event Card
// ═══════════════════════════════════════════════════════════════════════════════

class _CalendarEventCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _CalendarEventCard({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusLower = appointment.status.toLowerCase();
    final isCancelled = statusLower == 'cancelled';
    final isAttended = statusLower == 'attended';
    final isMissed = statusLower == 'missed';

    Color accentColor;
    if (isCancelled) { accentColor = AppColors.red; }
    else if (isAttended) { accentColor = AppColors.green; }
    else if (isMissed) { accentColor = AppColors.orange; }
    else { accentColor = AppColors.primary; }

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
        child: Row(children: [
          Container(width: 4, height: 44, decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.trainingTypeName.isNotEmpty ? appointment.trainingTypeName : 'Training',
                style: TextStyle(
                  color: isCancelled ? AppColors.muted : AppColors.text,
                  fontSize: 14, fontWeight: FontWeight.w700,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.access_time, size: 12, color: AppColors.muted),
                const SizedBox(width: 3),
                Text('$timeStr – $endTimeStr (${appointment.duration} Min.)',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(width: 8),
                const Icon(Icons.person_outline, size: 12, color: AppColors.muted),
                const SizedBox(width: 3),
                Expanded(child: Text(appointment.trainerName,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
              ]),
              if (appointment.locationName.isNotEmpty) ...[
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 12, color: AppColors.muted),
                  const SizedBox(width: 3),
                  Text(appointment.locationName, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ]),
              ],
            ],
          )),
          if (isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.red.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: const Text('Abgesagt', style: TextStyle(color: AppColors.red, fontSize: 11)),
            )
          else if (isMissed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.orange.withAlpha(25), borderRadius: BorderRadius.circular(8)),
              child: const Text('Verpasst', style: TextStyle(color: AppColors.orange, fontSize: 11)),
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
        ]),
      ),
    );
  }
}
