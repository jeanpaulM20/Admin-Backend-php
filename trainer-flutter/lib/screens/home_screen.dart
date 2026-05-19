import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/trainer.dart';
import '../models/training.dart';
import '../config/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final trainerProvider = context.watch<TrainerProvider>();
    final trainer = authProvider.trainer;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          if (trainer != null) {
            await trainerProvider.fetchTrainings(trainer.id);
          }
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context, trainer),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (trainer != null) _buildTrainerCard(context, trainer),
                  const SizedBox(height: 8),
                  _buildStatsRow(context, trainerProvider),
                  const SizedBox(height: 8),
                  _buildNextAppointment(context, trainerProvider),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, Trainer? trainer) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      snap: true,
      backgroundColor: AppColors.background,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.fitness_center, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'Sihl Training',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: AppColors.muted),
          onPressed: () => _confirmLogout(context),
          tooltip: 'Abmelden',
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Abmelden', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Möchtest du dich wirklich abmelden?',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Abmelden'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<TrainerProvider>().clearAll();
      context.read<AuthProvider>().logout();
    }
  }

  Widget _buildTrainerCard(BuildContext context, Trainer trainer) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(60),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _buildTrainerAvatar(trainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Willkommen zurück',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    trainer.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainerAvatar(Trainer trainer) {
    if (trainer.photo != null && trainer.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundColor: Colors.white24,
        backgroundImage: NetworkImage(trainer.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 34,
      backgroundColor: Colors.white24,
      child: Text(
        trainer.name.isNotEmpty ? trainer.name[0].toUpperCase() : 'T',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNextAppointment(BuildContext context, TrainerProvider provider) {
    final nextTraining = provider.nextTraining;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nächster Termin',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (provider.trainingsLoading)
            const _LoadingCard()
          else if (nextTraining != null)
            _AppointmentCard(training: nextTraining)
          else
            const _EmptyCard(
              icon: Icons.event_available,
              message: 'Keine anstehenden Termine',
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, TrainerProvider provider) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayCount = provider.trainings
        .where((t) =>
            !t.isCancelled &&
            t.startTime != null &&
            !t.startTime!.isBefore(todayStart) &&
            t.startTime!.isBefore(todayEnd))
        .length;

    // Trainings this week (Monday–Sunday)
    final dayOfWeek = now.weekday; // 1=Mon, 7=Sun
    final mondayStart = DateTime(now.year, now.month, now.day - (dayOfWeek - 1));
    final sundayEnd = mondayStart.add(const Duration(days: 7));
    final weekCount = provider.trainings
        .where((t) =>
            !t.isCancelled &&
            t.startTime != null &&
            !t.startTime!.isBefore(mondayStart) &&
            t.startTime!.isBefore(sundayEnd))
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
              child: _StatCard(
            label: 'Heute',
            value: todayCount.toString(),
            icon: Icons.fitness_center,
            color: AppColors.primary,
          )),
          const SizedBox(width: 10),
          Expanded(
              child: _StatCard(
            label: 'Diese Woche',
            value: weekCount.toString(),
            icon: Icons.date_range_rounded,
            color: const Color(0xFF1565C0),
          )),
        ],
      ),
    );
  }

  Widget _buildAboutSection(BuildContext context, TrainerProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Über Sihl Training',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (provider.aboutUsLoading)
            const _LoadingCard()
          else if (provider.aboutUsInfo != null)
            _AboutCard(info: provider.aboutUsInfo!)
          else
            const _EmptyCard(
              icon: Icons.info_outline,
              message: 'Studio-Infos nicht verfügbar',
            ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Training training;

  const _AppointmentCard({required this.training});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      training.clientName ?? training.title ?? 'Training',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (training.trainingType != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        training.trainingType!,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              _InfoChip(
                icon: Icons.calendar_today,
                text: training.displayDate,
              ),
              const SizedBox(width: 10),
              _InfoChip(
                icon: Icons.access_time,
                text: training.displayTime,
              ),
            ],
          ),
          if (training.locationName != null) ...[
            const SizedBox(height: 8),
            _InfoChip(
              icon: Icons.location_on_outlined,
              text: training.locationName!,
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(color: AppColors.text, fontSize: 13),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  final dynamic info;

  const _AboutCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (info.studioName != null)
            Text(
              info.studioName!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (info.description != null) ...[
            const SizedBox(height: 10),
            Text(
              info.description!,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
          if (info.address != null) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            _InfoChip(icon: Icons.location_on_outlined, text: info.address!),
          ],
          if (info.phone != null) ...[
            const SizedBox(height: 8),
            _InfoChip(icon: Icons.phone_outlined, text: info.phone!),
          ],
          if (info.email != null) ...[
            const SizedBox(height: 8),
            _InfoChip(icon: Icons.email_outlined, text: info.email!),
          ],
          if (info.trainers != null && info.trainers.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),
            const Text(
              'Unsere Trainer',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...info.trainers.map<Widget>((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withAlpha(40),
                        child: Text(
                          t.name.isNotEmpty ? t.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (t.specialization != null)
                              Text(
                                t.specialization!,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.muted, size: 22),
          const SizedBox(width: 10),
          Text(
            message,
            style: const TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
