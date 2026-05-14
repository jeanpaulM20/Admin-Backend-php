import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
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

  // Filter state
  String? _filterTrainerId;
  String? _filterTypeId;
  String? _filterLocationId;
  bool _prefsApplied = false;

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
      _applyPreferences();
    }
  }

  void _applyPreferences() {
    if (_prefsApplied) return;
    final pref = context.read<PreferenceProvider>();
    final calData = context.read<AppointmentProvider>().calendarData;
    if (calData == null) return;

    setState(() {
      // Apply preferences only if valid IDs exist in current data
      if (pref.trainerId != null &&
          calData.trainers.any((t) => t.id == pref.trainerId)) {
        _filterTrainerId = pref.trainerId;
      } else if (calData.trainers.length == 1) {
        _filterTrainerId = calData.trainers.first.id;
      }

      if (pref.trainingTypeId != null &&
          calData.trainingTypes.any((t) => t.id == pref.trainingTypeId)) {
        _filterTypeId = pref.trainingTypeId;
      }

      if (pref.locationId != null &&
          calData.locations.any((l) => l.id == pref.locationId)) {
        _filterLocationId = pref.locationId;
      }

      _prefsApplied = true;
    });
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

  /// Generate 30-minute time slots for the selected day based on availability + filters.
  List<_TimeSlot> _generateSlots(DateTime day, CalendarData calData) {
    const int slotDuration = 60; // training duration in minutes
    const int slotStep = 30; // grid step

    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    final now = DateTime.now();

    // 1. Filter availability by selected filters
    final filteredAvail = calData.availabilityIntervals.where((a) {
      if (a.date != dateStr) return false;
      if (_filterTrainerId != null && a.trainerId != _filterTrainerId) return false;
      if (_filterTypeId != null && a.trainingTypeId != null && a.trainingTypeId != _filterTypeId) return false;
      if (_filterLocationId != null && a.locationId != null && a.locationId != _filterLocationId) return false;
      return true;
    }).toList();

    if (filteredAvail.isEmpty) return [];

    // 2. Collect all 30-min slots that fit within availability windows
    final Set<int> availableMinutes = {};
    for (final a in filteredAvail) {
      final fromParts = a.from.split(':');
      final toParts = a.to.split(':');
      if (fromParts.length < 2 || toParts.length < 2) continue;
      final fromMin = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
      final toMin = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);

      for (int m = fromMin; m + slotDuration <= toMin; m += slotStep) {
        availableMinutes.add(m);
      }
    }

    if (availableMinutes.isEmpty) return [];

    // Get location buffer values
    final locationMap = <String, int>{};
    for (final loc in calData.locations) {
      locationMap[loc.id] = loc.bufferMinutes;
    }
    final selectedBuffer = _filterLocationId != null
        ? (locationMap[_filterLocationId!] ?? 30)
        : 30;

    // 3. Check each slot for conflicts
    final sorted = availableMinutes.toList()..sort();
    final slots = <_TimeSlot>[];

    for (final startMin in sorted) {
      final endMin = startMin + slotDuration;
      final timeStr = _minutesToTime(startMin);
      final endTimeStr = _minutesToTime(endMin);

      // Available slot's trainer (pick from filtered availability)
      final matchingAvail = filteredAvail.firstWhere(
        (a) {
          final fromParts = a.from.split(':');
          final toParts = a.to.split(':');
          if (fromParts.length < 2 || toParts.length < 2) return false;
          final fromMin = int.parse(fromParts[0]) * 60 + int.parse(fromParts[1]);
          final toMin = int.parse(toParts[0]) * 60 + int.parse(toParts[1]);
          return startMin >= fromMin && endMin <= toMin;
        },
        orElse: () => filteredAvail.first,
      );

      // 12h advance check — skip slot if too soon
      final slotDateTime = DateTime(day.year, day.month, day.day, startMin ~/ 60, startMin % 60);
      final hoursUntil = slotDateTime.difference(now).inMinutes / 60.0;
      if (hoursUntil < 12) continue;

      // Client double-booking check — skip slot if conflict
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

      // Trainer conflict + buffer check — skip slot if conflict
      bool trainerConflict = false;
      for (final b in calData.trainerBookings) {
        if (_filterTrainerId != null && b.trainerId != _filterTrainerId) continue;
        if (b.trainerId != matchingAvail.trainerId) continue;
        if (b.date != dateStr) continue;
        if (b.status.toLowerCase() == 'cancelled') continue;

        final parts = b.starttime.split(':');
        if (parts.length < 2) continue;
        final bStart = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        final bEnd = bStart + b.duration;

        // 3-tier buffer
        final sameLocation = _filterLocationId != null &&
            b.locationId != null &&
            b.locationId == _filterLocationId;
        int buffer = 0;
        if (!sameLocation) {
          final existingBuffer = b.locationId != null ? (locationMap[b.locationId!] ?? 30) : 30;
          buffer = selectedBuffer > existingBuffer ? selectedBuffer : existingBuffer;
        }

        if (startMin < bEnd + buffer && bStart < endMin + buffer) {
          trainerConflict = true;
          break;
        }
      }
      if (trainerConflict) continue;

      // Available!
      slots.add(_TimeSlot(
        startMin: startMin,
        timeStr: timeStr,
        endTimeStr: endTimeStr,
        trainerId: matchingAvail.trainerId,
        locationId: matchingAvail.locationId,
      ));
    }

    return slots;
  }

  String _minutesToTime(int minutes) {
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  // ── Booking ─────────────────────────────────────────────────────────────────

  Future<void> _bookSlot(_TimeSlot slot) async {
    final appt = context.read<AppointmentProvider>();
    final calData = appt.calendarData;
    if (calData == null) return;

    if (calData.credits <= 0) {
      _showNoCreditsDialog();
      return;
    }

    final bookingDay = _selectedDay ?? DateTime.now();
    final trainerId = slot.trainerId ?? _filterTrainerId ?? calData.defaultTrainerId;
    final typeId = _filterTypeId ?? calData.defaultTypeId;
    final locationId = slot.locationId ?? _filterLocationId;

    final trainerName = calData.trainers
        .where((t) => t.id == trainerId)
        .firstOrNull?.fullName ?? 'Trainer';
    final typeName = calData.trainingTypes
        .where((t) => t.id == typeId)
        .firstOrNull?.name ?? 'Training';
    final locationName = calData.locations
        .where((l) => l.id == locationId)
        .firstOrNull?.name ?? '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Buchung bestaetigen',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEEE, d. MMMM yyyy', 'de_DE').format(bookingDay),
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            _confirmRow('Uhrzeit', '${slot.timeStr} – ${slot.endTimeStr}'),
            _confirmRow('Trainer', trainerName),
            _confirmRow('Typ', typeName),
            if (locationName.isNotEmpty) _confirmRow('Ort', locationName),
            _confirmRow('Dauer', '60 Min.'),
            _confirmRow('Credits', '1 Credit'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Jetzt buchen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading
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
      trainerId: trainerId!,
      trainingTypeId: typeId!,
      date: DateFormat('yyyy-MM-dd').format(bookingDay),
      starttime: slot.timeStr,
      locationId: locationId,
      duration: 60,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Save current filter as preference (auto-remember last booking choices)
      if (success) {
        final prefProvider = context.read<PreferenceProvider>();
        prefProvider.savePreferences(auth.clientId!, {
          'trainer_id': trainerId,
          'training_type_id': typeId,
          'location_id': locationId,
        }).catchError((_) {}); // fire-and-forget
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
  }

  void _showNoCreditsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Keine Credits verfuegbar',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Du hast keine verfuegbaren Credits mehr. '
          'Bitte kaufe neue Credits, um Termine buchen zu koennen.',
          style: TextStyle(color: AppColors.text, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schliessen', style: TextStyle(color: AppColors.muted)),
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
            const Text('Moechtest du diesen Termin wirklich absagen?',
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
                    'Verspaetete Absage (weniger als 12 Stunden). Dein Credit wird nicht zurueckerstattet.',
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
                    'Dein Credit wird automatisch zurueckerstattet.',
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
    final success = await provider.cancelAppointment(auth.clientId!, appt.id);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? (isLateCancellation
                  ? 'Termin abgesagt – Credit wurde nicht zurueckerstattet.'
                  : 'Termin abgesagt – Credit wurde zurueckerstattet.')
              : provider.error ?? 'Absage fehlgeschlagen'),
          backgroundColor: success
              ? (isLateCancellation ? AppColors.orange : AppColors.green)
              : AppColors.red,
        ),
      );
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
    final url = Uri.parse('${ApiConfig.baseUrl}api/training/${appt.id}/ical');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
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

                                  return Positioned(
                                    bottom: 2,
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      if (avails.isNotEmpty) _markerDot(AppColors.green),
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

                        // ── Filter Bar ──
                        if (calData != null)
                          SliverToBoxAdapter(
                            child: _FilterBar(
                              calData: calData,
                              filterTrainerId: _filterTrainerId,
                              filterTypeId: _filterTypeId,
                              filterLocationId: _filterLocationId,
                              onTrainerChanged: (v) => setState(() => _filterTrainerId = v),
                              onTypeChanged: (v) => setState(() => _filterTypeId = v),
                              onLocationChanged: (v) => setState(() => _filterLocationId = v),
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
                                  Text('Keine Verfuegbarkeit an diesem Tag',
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
                                  Icon(Icons.filter_alt_outlined, color: AppColors.orange, size: 28),
                                  SizedBox(height: 8),
                                  Text('Keine Slots fuer aktuelle Filter',
                                      style: TextStyle(color: AppColors.orange, fontSize: 14)),
                                  SizedBox(height: 4),
                                  Text('Passe Trainer, Typ oder Standort an',
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
// Filter Bar Widget
// ═══════════════════════════════════════════════════════════════════════════════

class _FilterBar extends StatelessWidget {
  final CalendarData calData;
  final String? filterTrainerId;
  final String? filterTypeId;
  final String? filterLocationId;
  final ValueChanged<String?> onTrainerChanged;
  final ValueChanged<String?> onTypeChanged;
  final ValueChanged<String?> onLocationChanged;

  const _FilterBar({
    required this.calData,
    this.filterTrainerId,
    this.filterTypeId,
    this.filterLocationId,
    required this.onTrainerChanged,
    required this.onTypeChanged,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.tune, size: 14, color: AppColors.muted),
              SizedBox(width: 6),
              Text('Filter', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Trainer chips
                if (calData.trainers.length > 1)
                  ...calData.trainers.map((t) => _FilterChip(
                    label: t.fullName,
                    selected: filterTrainerId == t.id,
                    onTap: () => onTrainerChanged(filterTrainerId == t.id ? null : t.id),
                    color: AppColors.primary,
                  )),
                if (calData.trainers.length == 1)
                  _FilterChip(
                    label: calData.trainers.first.fullName,
                    selected: true,
                    onTap: () {},
                    color: AppColors.primary,
                  ),

                // Divider dot
                if (calData.trainers.length > 1 && calData.locations.isNotEmpty)
                  Container(
                    width: 3, height: 3, margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle),
                  ),

                // Location chips
                ...calData.locations.map((l) => _FilterChip(
                  label: l.name,
                  selected: filterLocationId == l.id,
                  onTap: () => onLocationChanged(filterLocationId == l.id ? null : l.id),
                  color: AppColors.blue,
                  suffix: l.bufferMinutes == 60 ? ' (ext.)' : null,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final String? suffix;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.color,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color.withAlpha(80) : AppColors.border),
        ),
        child: Text(
          '$label${suffix ?? ''}',
          style: TextStyle(
            color: selected ? color : AppColors.muted,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
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
  final String? trainerId;
  final String? locationId;

  const _TimeSlot({
    required this.startMin,
    required this.timeStr,
    required this.endTimeStr,
    this.trainerId,
    this.locationId,
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
              Text('Verfuegbare Slots', style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
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
