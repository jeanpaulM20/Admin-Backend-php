import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/availability.dart';
import '../models/training.dart';
import '../config/app_colors.dart';
import 'training_detail_screen.dart';
import 'availability_serial_screen.dart';
import 'book_training_dialog.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialLoad();
    });
  }

  Future<void> _initialLoad() async {
    final authProvider = context.read<AuthProvider>();
    final trainerProvider = context.read<TrainerProvider>();
    final trainer = authProvider.trainer;
    if (trainer == null) return;

    setState(() => _error = null);

    try {
      if (trainerProvider.locations.isEmpty) {
        await trainerProvider.fetchLocations();
      }

      // Load availability for all locations
      await trainerProvider.fetchAvailability(trainer.id, 0);

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(
            () => _error = 'Verfügbarkeit konnte nicht geladen werden');
      }
    }
  }

  Future<void> _refresh() async {
    setState(() => _error = null);
    await _initialLoad();
  }

  Future<void> _openBookingDialog(TrainerProvider trainerProvider) async {
    final trainer = context.read<AuthProvider>().trainer;
    if (trainer == null) return;

    final booked = await BookTrainingDialog.show(
      context,
      trainerId: trainer.id,
      locations: trainerProvider.locations,
      initialDate: _selectedDay,
    );

    if (booked == true) {
      _refresh();
    }
  }

  /// Availability slots for a given day (shown for ALL locations — trainer
  /// availability is global, not location-specific).
  List<AvailabilitySlot> _getSlotsForDay(
      DateTime day, Map<DateTime, List<AvailabilitySlot>> map) {
    final key = DateTime(day.year, day.month, day.day);
    return map[key] ?? [];
  }

  /// Trainings for a specific calendar day, filtered by selected location.
  /// Cancelled trainings are hidden unless they are late cancellations
  /// (cancelled < 12h before start) — those are still billed.
  List<Training> _getTrainingsForDay(
      DateTime day, List<Training> trainings) {
    return trainings.where((t) {
      if (t.isCancelled && !t.isLateCancellation) return false;
      // Trainings werden standortübergreifend angezeigt (kein Location-Filter)
      if (t.startTime != null) {
        return t.startTime!.year == day.year &&
            t.startTime!.month == day.month &&
            t.startTime!.day == day.day;
      }
      if (t.date != null) {
        final parsed = DateTime.tryParse(t.date!);
        if (parsed != null) {
          return parsed.year == day.year &&
              parsed.month == day.month &&
              parsed.day == day.day;
        }
      }
      return false;
    }).toList()
      ..sort((a, b) {
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return a.startTime!.compareTo(b.startTime!);
      });
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();
    final daySlots = _selectedDay != null
        ? _getSlotsForDay(_selectedDay!, trainerProvider.availabilityMap)
        : <AvailabilitySlot>[];
    final dayTrainings = _selectedDay != null
        ? _getTrainingsForDay(_selectedDay!, trainerProvider.trainings)
        : <Training>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openBookingDialog(trainerProvider),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      appBar: AppBar(
        title: const Text('Kalender'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event_repeat),
            tooltip: 'Serientermine',
            onPressed: () {
              final trainer = context.read<AuthProvider>().trainer;
              if (trainer == null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AvailabilitySerialScreen(trainerId: trainer.id),
                ),
              ).then((_) => _refresh());
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null) _buildErrorBanner(),
          _buildCalendar(trainerProvider),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: _buildDayDetail(
              daySlots,
              dayTrainings,
              trainerProvider.availabilityLoading,
            ),
          ),
        ],
      ),
    );
  }

  // ── Error banner ────────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.red.withAlpha(30),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.red, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Erneut', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Calendar ────────────────────────────────────────────────────────────────

  Widget _buildCalendar(TrainerProvider provider) {
    return TableCalendar<Object>(
      locale: 'de_DE',
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      startingDayOfWeek: StartingDayOfWeek.monday,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) {
        // Return combined list so markerBuilder fires for both types
        final slots = _getSlotsForDay(day, provider.availabilityMap);
        final trainings = _getTrainingsForDay(day, provider.trainings);
        return [...slots, ...trainings];
      },
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        // No refetch needed — backend returns all availability data
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle:
            const TextStyle(color: AppColors.text, fontSize: 14),
        weekendTextStyle:
            const TextStyle(color: AppColors.text, fontSize: 14),
        selectedDecoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.primary.withAlpha(60),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        selectedTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        markersMaxCount: 4,
        outsideTextStyle:
            const TextStyle(color: AppColors.muted, fontSize: 14),
        disabledTextStyle:
            const TextStyle(color: AppColors.border, fontSize: 14),
        cellMargin: const EdgeInsets.all(4),
        rowDecoration:
            const BoxDecoration(color: Colors.transparent),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: true,
        titleCentered: true,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        leftChevronIcon:
            const Icon(Icons.chevron_left, color: AppColors.muted),
        rightChevronIcon:
            const Icon(Icons.chevron_right, color: AppColors.muted),
        formatButtonTextStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 13,
        ),
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
        headerPadding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          final slots = events.whereType<AvailabilitySlot>().toList();
          final trainings = events.whereType<Training>().toList();

          if (slots.isEmpty && trainings.isEmpty) return null;

          final freeCount = slots.where((e) => !e.isBooked).length;
          final bookedCount = slots.where((e) => e.isBooked).length;
          final activeCount = trainings.where((t) => !t.isCancelled).length;
          final lateCancel = trainings.where((t) => t.isLateCancellation).length;

          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (freeCount > 0)
                  _calDot(AppColors.green),
                if (bookedCount > 0)
                  _calDot(AppColors.primary),
                if (activeCount > 0)
                  _calCountDot(AppColors.orange, activeCount),
                if (lateCancel > 0)
                  _calDot(AppColors.red),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _calDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _calCountDot(Color color, int count) {
    if (count <= 1) return _calDot(color);
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

  // ── Day detail list (trainings + availability) ─────────────────────────────

  Widget _buildDayDetail(
      List<AvailabilitySlot> slots,
      List<Training> trainings,
      bool loading) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      );
    }

    if (_selectedDay == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, color: AppColors.muted, size: 36),
            SizedBox(height: 12),
            Text(
              'Tippe auf einen Tag',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (slots.isEmpty && trainings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, color: AppColors.muted, size: 36),
            const SizedBox(height: 12),
            Text(
              'Keine Einträge am ${DateFormat('d. MMMM yyyy', 'de_DE').format(_selectedDay!)}',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      children: [
        // ── Date header + legend ──
        Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE, d. MMMM', 'de_DE').format(_selectedDay!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _buildLegend(
              hasSlots: slots.isNotEmpty,
              hasTrainings: trainings.isNotEmpty,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Trainings section ──
        if (trainings.isNotEmpty) ...[
          _sectionHeader(
            Icons.fitness_center,
            'Termine',
            trainings.length,
            AppColors.orange,
          ),
          const SizedBox(height: 6),
          for (final t in trainings)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TrainingDayCard(
                training: t,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TrainingDetailScreen(training: t),
                  ),
                ),
              ),
            ),
          if (slots.isNotEmpty) const SizedBox(height: 4),
        ],

        // ── Availability section ──
        if (slots.isNotEmpty) ...[
          _sectionHeader(
            Icons.schedule,
            'Verfügbarkeit',
            slots.length,
            AppColors.green,
          ),
          const SizedBox(height: 6),
          for (final s in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SlotCard(
                slot: s,
                onTap: () => _showSlotActions(s),
              ),
            ),
        ],
      ],
    );
  }

  // ── Slot actions bottom sheet ─────────────────────────────────────────────

  void _showSlotActions(AvailabilitySlot slot) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title
                Row(
                  children: [
                    const Icon(Icons.schedule,
                        color: AppColors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verfügbarkeit',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${slot.displayTime}${slot.locationName != null ? ' · ${slot.locationName}' : ''}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: slot.isBooked
                            ? AppColors.primary.withAlpha(30)
                            : AppColors.green.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        slot.isBooked ? 'Gebucht' : 'Verfügbar',
                        style: TextStyle(
                          color: slot.isBooked
                              ? AppColors.primary
                              : AppColors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (slot.date != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: AppColors.muted, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, d. MMMM yyyy', 'de_DE')
                            .format(slot.slotDate ?? DateTime.now()),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                // ── Action buttons ──
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _editSlotTime(slot);
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Bearbeiten'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: slot.isBooked
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                _deleteSlot(slot);
                              },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: Text(slot.isBooked
                            ? 'Gebucht'
                            : 'Löschen'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: BorderSide(
                            color: slot.isBooked
                                ? AppColors.muted.withOpacity(0.3)
                                : AppColors.red,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editSlotTime(AvailabilitySlot slot) async {
    // Parse current from/to times
    TimeOfDay? currentFrom;
    TimeOfDay? currentTo;
    if (slot.timeFrom != null) {
      final parts = slot.timeFrom!.split(':');
      if (parts.length >= 2) {
        currentFrom = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }
    if (slot.timeTo != null) {
      final parts = slot.timeTo!.split(':');
      if (parts.length >= 2) {
        currentTo = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 10,
          minute: int.tryParse(parts[1]) ?? 0,
        );
      }
    }

    currentFrom ??= const TimeOfDay(hour: 9, minute: 0);
    currentTo ??= const TimeOfDay(hour: 10, minute: 0);

    // Pick new "from" time
    final newFrom = await showTimePicker(
      context: context,
      initialTime: currentFrom,
      helpText: 'Startzeit wählen',
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
    if (newFrom == null || !mounted) return;

    // Pick new "to" time
    final newTo = await showTimePicker(
      context: context,
      initialTime: currentTo,
      helpText: 'Endzeit wählen',
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
    if (newTo == null || !mounted) return;

    final fromStr =
        '${newFrom.hour.toString().padLeft(2, '0')}:${newFrom.minute.toString().padLeft(2, '0')}';
    final toStr =
        '${newTo.hour.toString().padLeft(2, '0')}:${newTo.minute.toString().padLeft(2, '0')}';

    final provider = context.read<TrainerProvider>();
    final success =
        await provider.updateAvailability(slot.id, from: fromStr, to: toStr);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verfügbarkeit aktualisiert'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Aktualisieren'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSlot(AvailabilitySlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verfügbarkeit löschen?',
            style: TextStyle(color: Colors.white, fontSize: 17)),
        content: Text(
          'Slot ${slot.displayTime} am ${slot.date ?? 'diesem Tag'} wirklich löschen?',
          style: const TextStyle(color: AppColors.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final provider = context.read<TrainerProvider>();
    final success = await provider.deleteAvailability(slot.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verfügbarkeit gelöscht'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        setState(() {}); // Refresh the UI with updated local state
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fehler beim Löschen'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Widget _sectionHeader(
      IconData icon, String title, int count, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend({
    required bool hasSlots,
    required bool hasTrainings,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSlots) ...[
          const _LegendDot(color: AppColors.green, label: 'Frei'),
          const SizedBox(width: 8),
          const _LegendDot(color: AppColors.primary, label: 'Gebucht'),
        ],
        if (hasSlots && hasTrainings) const SizedBox(width: 8),
        if (hasTrainings)
          const _LegendDot(color: AppColors.orange, label: 'Termin'),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Private widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final AvailabilitySlot slot;
  final VoidCallback? onTap;

  const _SlotCard({required this.slot, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isBooked = slot.isBooked;
    final statusColor =
        isBooked ? AppColors.primary : const Color(0xFF2E7D32);
    final bgColor = isBooked
        ? AppColors.primary.withAlpha(15)
        : const Color(0xFF2E7D32).withAlpha(15);
    final borderColor = isBooked
        ? AppColors.primary.withAlpha(50)
        : const Color(0xFF2E7D32).withAlpha(50);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.displayTime,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (slot.locationName != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        slot.locationName!,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBooked ? 'Gebucht' : 'Verfügbar',
              style: TextStyle(
                color: isBooked
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF66BB6A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _TrainingDayCard extends StatelessWidget {
  final Training training;
  final VoidCallback onTap;

  const _TrainingDayCard({
    required this.training,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = training.isCancelled;
    final accentColor = isCancelled ? AppColors.red : AppColors.orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withAlpha(12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withAlpha(50)),
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
                    training.clientName ??
                        training.title ??
                        'Training',
                    style: TextStyle(
                      color: isCancelled ? AppColors.muted : Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        training.displayTime,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                      if (training.locationName != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            training.locationName!,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (training.trainingType != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      training.trainingType!,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
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
                  color: AppColors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Abgesagt',
                  style: TextStyle(color: AppColors.red, fontSize: 11),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: AppColors.muted,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
