import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/availability.dart';
import '../models/training.dart';
import 'training_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  int? _selectedLocationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    final trainerProvider = context.read<TrainerProvider>();
    final trainer = authProvider.trainer;
    if (trainer == null) return;

    if (trainerProvider.locations.isEmpty) {
      await trainerProvider.fetchLocations();
    }

    final locationId = _selectedLocationId ??
        (trainerProvider.locations.isNotEmpty
            ? trainerProvider.locations.first.id
            : 1);

    await trainerProvider.fetchAvailability(
      trainer.id,
      locationId,
      from: DateTime(_focusedDay.year, _focusedDay.month, 1),
      to: DateTime(_focusedDay.year, _focusedDay.month + 1, 0),
    );
  }

  List<AvailabilitySlot> _getSlotsForDay(
      DateTime day, Map<DateTime, List<AvailabilitySlot>> map) {
    final key = DateTime(day.year, day.month, day.day);
    return map[key] ?? [];
  }

  List<Training> _getTrainingsForDay(
      DateTime day, List<Training> trainings) {
    return trainings.where((t) {
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
    }).toList();
  }

  void _showTrainingsBottomSheet(
      BuildContext context, DateTime day, List<Training> trainings) {
    if (trainings.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252525),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF555555),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      const Icon(Icons.fitness_center,
                          color: Color(0xFF8B2020), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE, MMMM d').format(day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B2020).withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${trainings.length} session${trainings.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            color: Color(0xFFB03030),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF333333)),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: trainings.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = trainings[index];
                      return _TrainingBottomSheetItem(
                        training: t,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TrainingDetailScreen(training: t),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();
    final slots = _selectedDay != null
        ? _getSlotsForDay(_selectedDay!, trainerProvider.availabilityMap)
        : <AvailabilitySlot>[];

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        title: const Text('Availability Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          if (trainerProvider.locations.isNotEmpty)
            _buildLocationSelector(trainerProvider),
          _buildCalendar(trainerProvider),
          const Divider(height: 1, color: Color(0xFF333333)),
          Expanded(
            child: _buildSlotList(slots, trainerProvider.availabilityLoading),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector(TrainerProvider provider) {
    return Container(
      height: 44,
      color: const Color(0xFF1E1E1E),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: provider.locations.length,
        itemBuilder: (context, index) {
          final loc = provider.locations[index];
          final isSelected = _selectedLocationId == loc.id ||
              (_selectedLocationId == null && index == 0);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedLocationId = loc.id);
                _loadData();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF8B2020)
                      : const Color(0xFF2E2E2E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF8B2020)
                        : const Color(0xFF444444),
                  ),
                ),
                child: Text(
                  loc.name,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF9E9E9E),
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(TrainerProvider provider) {
    return TableCalendar<AvailabilitySlot>(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2030, 12, 31),
      focusedDay: _focusedDay,
      calendarFormat: _calendarFormat,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: (day) =>
          _getSlotsForDay(day, provider.availabilityMap),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
        final trainingsForDay =
            _getTrainingsForDay(selectedDay, provider.trainings);
        if (trainingsForDay.isNotEmpty) {
          _showTrainingsBottomSheet(context, selectedDay, trainingsForDay);
        }
      },
      onFormatChanged: (format) {
        setState(() => _calendarFormat = format);
      },
      onPageChanged: (focusedDay) {
        _focusedDay = focusedDay;
        _loadData();
      },
      calendarStyle: CalendarStyle(
        outsideDaysVisible: false,
        defaultTextStyle:
            const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
        weekendTextStyle:
            const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        selectedDecoration: BoxDecoration(
          color: const Color(0xFF8B2020),
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: const Color(0xFF8B2020).withAlpha(60),
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
        markerDecoration: BoxDecoration(
          color: const Color(0xFF4CAF50),
          shape: BoxShape.circle,
        ),
        markersMaxCount: 3,
        outsideTextStyle:
            const TextStyle(color: Color(0xFF555555), fontSize: 14),
        disabledTextStyle:
            const TextStyle(color: Color(0xFF444444), fontSize: 14),
        cellMargin: const EdgeInsets.all(4),
        rowDecoration: const BoxDecoration(color: Colors.transparent),
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
            const Icon(Icons.chevron_left, color: Color(0xFF9E9E9E)),
        rightChevronIcon:
            const Icon(Icons.chevron_right, color: Color(0xFF9E9E9E)),
        formatButtonTextStyle: const TextStyle(
          color: Color(0xFFB03030),
          fontSize: 13,
        ),
        formatButtonDecoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF8B2020)),
          borderRadius: BorderRadius.circular(8),
        ),
        headerPadding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(color: Colors.transparent),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          color: Color(0xFF9E9E9E),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        weekendStyle: TextStyle(
          color: Color(0xFF777777),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          final bookedCount = events.where((e) => e.isBooked).length;
          final freeCount = events.where((e) => !e.isBooked).length;
          return Positioned(
            bottom: 2,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (freeCount > 0)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
                if (bookedCount > 0)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B2020),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotList(List<AvailabilitySlot> slots, bool loading) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8B2020),
          strokeWidth: 2,
        ),
      );
    }

    if (_selectedDay == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, color: Color(0xFF555555), size: 36),
            SizedBox(height: 12),
            Text(
              'Select a day to view availability',
              style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (slots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, color: Color(0xFF555555), size: 36),
            const SizedBox(height: 12),
            Text(
              'No availability on ${DateFormat('MMMM d, yyyy').format(_selectedDay!)}',
              style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Text(
                DateFormat('EEEE, MMMM d').format(_selectedDay!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              _buildLegend(),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _SlotCard(slot: slots[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _LegendDot(color: const Color(0xFF4CAF50), label: 'Free'),
        const SizedBox(width: 10),
        _LegendDot(color: const Color(0xFF8B2020), label: 'Booked'),
      ],
    );
  }
}

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
            style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 11)),
      ],
    );
  }
}

class _SlotCard extends StatelessWidget {
  final AvailabilitySlot slot;

  const _SlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final isBooked = slot.isBooked;
    final statusColor =
        isBooked ? const Color(0xFF8B2020) : const Color(0xFF2E7D32);
    final bgColor = isBooked
        ? const Color(0xFF8B2020).withAlpha(15)
        : const Color(0xFF2E7D32).withAlpha(15);
    final borderColor = isBooked
        ? const Color(0xFF8B2020).withAlpha(50)
        : const Color(0xFF2E7D32).withAlpha(50);

    return Container(
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
                          size: 13, color: Color(0xFF9E9E9E)),
                      const SizedBox(width: 4),
                      Text(
                        slot.locationName!,
                        style: const TextStyle(
                            color: Color(0xFF9E9E9E), fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isBooked ? 'Booked' : 'Available',
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
    );
  }
}

class _TrainingBottomSheetItem extends StatelessWidget {
  final Training training;
  final VoidCallback onTap;

  const _TrainingBottomSheetItem({
    required this.training,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = training.isCancelled;
    final accentColor =
        isCancelled ? const Color(0xFF555555) : const Color(0xFF8B2020);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: accentColor.withAlpha(60), width: 0.5),
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
                  if (training.clientName != null)
                    Text(
                      training.clientName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    training.displayTime,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 13,
                    ),
                  ),
                  if (training.trainingType != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      training.trainingType!,
                      style: const TextStyle(
                        color: Color(0xFF777777),
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
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Cancelled',
                  style: TextStyle(color: Color(0xFF777777), fontSize: 11),
                ),
              )
            else
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF555555),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
