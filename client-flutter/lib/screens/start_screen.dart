import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../config/app_colors.dart';
import '../providers/auth_provider.dart';
import '../providers/appointment_provider.dart';
import '../providers/daily_quote_provider.dart';
import '../models/appointment.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/error_view.dart';

class StartScreen extends StatefulWidget {
  final VoidCallback? onGoToCalendar;
  const StartScreen({super.key, this.onGoToCalendar});

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
    // Quote loads independently — non-blocking, cached per day
    context.read<DailyQuoteProvider>().load();
  }

  @override
  Widget build(BuildContext context) {
    final appt  = context.watch<AppointmentProvider>();
    final quote = context.watch<DailyQuoteProvider>();
    final firstName = appt.startData?.firstName ?? '';
    final totalCredits = appt.startData?.totalCredits ?? 0;

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
                                const SizedBox(height: 16),

                                // ── Daily Quote ──
                                _DailyQuoteWidget(isLoading: quote.isLoading, quote: quote.quote),

                                // Two summary cards side by side
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _SummaryCard(
                                        icon: Icons.calendar_today_outlined,
                                        value: nextAppt != null
                                            ? DateFormat('dd.MM.  HH:mm').format(nextAppt.startDate)
                                            : '–',
                                        label: 'Nächster Termin',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _SummaryCard(
                                        icon: Icons.toll_outlined,
                                        value: '$totalCredits',
                                        label: 'Credits',
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
                                  _EmptyState(onBookNow: widget.onGoToCalendar)
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

// ─── Daily Quote ──────────────────────────────────────────────────────────────

class _DailyQuoteWidget extends StatelessWidget {
  final bool isLoading;
  final dynamic quote; // DailyQuote?

  const _DailyQuoteWidget({required this.isLoading, required this.quote});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const _QuoteShimmer();
    if (quote == null) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '„${quote.text}“',
            style: GoogleFonts.inter(
              color: AppColors.text.withAlpha(140),
              fontSize: 13,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '— ${quote.author}',
            style: GoogleFonts.inter(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _QuoteShimmer extends StatefulWidget {
  const _QuoteShimmer();
  @override
  State<_QuoteShimmer> createState() => _QuoteShimmerState();
}

class _QuoteShimmerState extends State<_QuoteShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: 220,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 10,
                width: 120,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
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
  final VoidCallback? onBookNow;
  const _EmptyState({this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.calendar_today_rounded,
            color: AppColors.muted,
            size: 32,
          ),
          const SizedBox(height: 16),
          const Text(
            'Suche Dir einen passenden Termin aus.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (onBookNow != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onBookNow,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Termin buchen'),
            ),
          ],
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Date bubble
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(38),
              borderRadius: BorderRadius.circular(8),
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
                Text(
                  '$timeStr · ${appointment.duration} Min.',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                if (appointment.trainerName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    appointment.trainerName,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              appointment.status == 'booked' ? 'Gebucht' : appointment.status,
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
