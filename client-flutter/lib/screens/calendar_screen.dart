import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment.dart';
import '../models/calendar_data.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

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
    }).toList();
  }

  void _showBookingDialog() {
    final appt = context.read<AppointmentProvider>();
    final calData = appt.calendarData;
    if (calData == null || calData.trainers.isEmpty) return;

    String? selectedTrainerId = calData.defaultTrainerId;
    String? selectedTypeId = calData.defaultTypeId;
    String? selectedLocationId =
        calData.locations.isNotEmpty ? calData.locations.first.id : null;
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Termin buchen',
              style: TextStyle(color: AppColors.text)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                  onChanged: (v) =>
                      setDialogState(() => selectedTrainerId = v),
                ),
                const SizedBox(height: 12),

                // Type dropdown
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
                      .map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedTypeId = v),
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
                        .map((l) =>
                            DropdownMenuItem(value: l.id, child: Text(l.name)))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedLocationId = v),
                  ),
                const SizedBox(height: 16),

                // Time picker
                InkWell(
                  onTap: () async {
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setDialogState(() => selectedTime = time);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            color: AppColors.muted, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          selectedTime.format(ctx),
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected date info
                const SizedBox(height: 12),
                Text(
                  'Datum: ${_selectedDay != null ? DateFormat('dd.MM.yyyy').format(_selectedDay!) : '-'}',
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen',
                  style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedTrainerId == null ||
                    selectedTypeId == null ||
                    _selectedDay == null) return;
                Navigator.pop(ctx);
                final auth = context.read<AuthProvider>();
                final timeStr =
                    '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                await appt.bookAppointment(
                  auth.clientId!,
                  trainerId: selectedTrainerId!,
                  trainingTypeId: selectedTypeId!,
                  date: DateFormat('yyyy-MM-dd').format(_selectedDay!),
                  starttime: timeStr,
                  locationId: selectedLocationId,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Termin gebucht!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Buchen'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appt = context.watch<AppointmentProvider>();
    final events = _selectedDay != null ? _getEventsForDay(_selectedDay!) : [];

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: _showBookingDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: AppColors.white),
      ),
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
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: TableCalendar<Appointment>(
                              firstDay: DateTime.now()
                                  .subtract(const Duration(days: 365)),
                              lastDay: DateTime.now()
                                  .add(const Duration(days: 365)),
                              focusedDay: _focusedDay,
                              selectedDayPredicate: (day) =>
                                  isSameDay(_selectedDay, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  _selectedDay = selectedDay;
                                  _focusedDay = focusedDay;
                                });
                              },
                              onPageChanged: (focusedDay) {
                                _focusedDay = focusedDay;
                              },
                              eventLoader: _getEventsForDay,
                              calendarStyle: CalendarStyle(
                                todayDecoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.3),
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
                                defaultTextStyle:
                                    const TextStyle(color: AppColors.text),
                                weekendTextStyle:
                                    const TextStyle(color: AppColors.muted),
                                outsideTextStyle: TextStyle(
                                    color: AppColors.muted.withOpacity(0.4)),
                                markerSize: 6,
                                markersMaxCount: 3,
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
                                    color: AppColors.muted, fontSize: 12),
                                weekendStyle: TextStyle(
                                    color: AppColors.muted, fontSize: 12),
                              ),
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              locale: 'de_DE',
                            ),
                          ),
                        ),

                        // Events for selected day
                        SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: events.isEmpty
                              ? SliverToBoxAdapter(
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Keine Termine an diesem Tag',
                                        style: TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 14),
                                      ),
                                    ),
                                  ),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (ctx, i) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 10),
                                      child: _CalendarEventCard(
                                          appointment:
                                              events[i] as Appointment),
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
}

class _CalendarEventCard extends StatelessWidget {
  final Appointment appointment;
  const _CalendarEventCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(appointment.startDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
                Text(
                  appointment.trainingTypeName.isNotEmpty
                      ? appointment.trainingTypeName
                      : 'Training',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$timeStr - ${appointment.duration} Min. | ${appointment.trainerName}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
