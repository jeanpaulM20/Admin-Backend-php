import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../config/app_colors.dart';
import '../models/appointment.dart';
import '../providers/auth_provider.dart';
import '../providers/client_provider.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay  = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final clientId = context.read<AuthProvider>().clientId;
    if (clientId != null) {
      await context.read<ClientProvider>().fetchCalendar(clientId);
    }
  }

  List<Appointment> _eventsForDay(DateTime day, List<Appointment> all) {
    final fmt = DateFormat('yyyy-MM-dd');
    final key = fmt.format(day);
    return all.where((a) => a.date == key).toList();
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<ClientProvider>();
    final events = _eventsForDay(_selectedDay ?? DateTime.now(), prov.allAppointments);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Kalender',
            style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.muted),
            onPressed: _load,
          ),
        ],
      ),
      body: prov.isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : Column(
              children: [
                TableCalendar<Appointment>(
                  firstDay: DateTime.now().subtract(const Duration(days: 180)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
                  eventLoader: (d) => _eventsForDay(d, prov.allAppointments),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    defaultTextStyle:
                        const TextStyle(color: AppColors.text),
                    weekendTextStyle:
                        const TextStyle(color: AppColors.text),
                    selectedDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle:
                        TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
                    leftChevronIcon:
                        Icon(Icons.chevron_left, color: AppColors.muted),
                    rightChevronIcon:
                        Icon(Icons.chevron_right, color: AppColors.muted),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                    weekendStyle: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay  = focused;
                    });
                  },
                  onPageChanged: (f) => setState(() => _focusedDay = f),
                ),
                const Divider(color: AppColors.border, height: 1),
                Expanded(
                  child: events.isEmpty
                      ? const Center(
                          child: Text(
                            'Kein Training an diesem Tag',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: events.length,
                          itemBuilder: (ctx, i) => _EventTile(event: events[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final Appointment event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              event.timeFrom,
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.typeName,
                    style: const TextStyle(
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                if (event.trainerName.isNotEmpty)
                  Text('mit ${event.trainerName}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                if (event.location != null)
                  Text(event.location!,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          if (event.isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Abgesagt',
                  style: TextStyle(color: AppColors.red, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
