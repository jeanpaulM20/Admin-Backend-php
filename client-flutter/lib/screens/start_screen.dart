import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../models/appointment.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final auth = context.read<AuthProvider>();
    if (auth.clientId != null) {
      await context.read<AppointmentProvider>().fetchStart(auth.clientId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appt = context.watch<AppointmentProvider>();
    final auth = context.watch<AuthProvider>();
    final firstName = appt.startData?.firstName ?? '';

    // Dynamic greeting based on time of day
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Guten Morgen,'
        : hour < 18
            ? 'Guten Tag,'
            : 'Guten Abend,';
    final appointments = appt.startData?.appointments ?? [];

    // Find the next appointment
    final now = DateTime.now();
    final upcoming = appointments.where((a) => a.startDate.isAfter(now)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final nextAppt = upcoming.isNotEmpty ? upcoming.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: appt.isLoading
              ? const LoadingIndicator(message: 'Lade Daten...')
              : appt.error != null
                  ? ErrorView(message: appt.error!, onRetry: _loadData)
                  : CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Greeting
                                Text(
                                  greeting,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  firstName.isNotEmpty
                                      ? '$firstName!'
                                      : 'Willkommen!',
                                  style: const TextStyle(
                                    color: AppColors.text,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Two summary cards side by side
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _SummaryCard(
                                        icon: Icons.calendar_today_outlined,
                                        value: nextAppt != null
                                            ? DateFormat('dd.MM.yyyy').format(nextAppt.startDate)
                                            : '–',
                                        label: 'Nächster Termin',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _SummaryCard(
                                        icon: Icons.check_box_outlined,
                                        value: '${appointments.length}',
                                        label: 'Termine gesamt',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // Section header with green accent
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Text(
                                      'Nächste Termine',
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${upcoming.length}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (upcoming.isEmpty)
                                  _EmptyState()
                                else
                                  ...upcoming.map((a) => Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: _AppointmentCard(appointment: a),
                                      )),
                              ],
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

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: AppColors.muted,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Keine bevorstehenden Termine',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Buche einen Termin im Kalender, um loszulegen.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final dateStr =
        DateFormat('EE, d. MMM', 'de_DE').format(appointment.startDate);
    final timeStr = DateFormat('HH:mm').format(appointment.startDate);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Date bubble
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('dd').format(appointment.startDate),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  DateFormat('MMM', 'de_DE').format(appointment.startDate),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      '$timeStr - ${appointment.duration} Min.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (appointment.trainerName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 14, color: AppColors.muted),
                      const SizedBox(width: 4),
                      Text(
                        appointment.trainerName,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              appointment.status == 'booked' ? 'Gebucht' : appointment.status,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
