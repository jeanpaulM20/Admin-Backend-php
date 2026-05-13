import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/training.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import 'training_detail_screen.dart';
import 'anamnese_screen.dart';
import 'training_plan_list_screen.dart';
import 'performance_screen.dart';
import 'client_files_screen.dart';
import 'workout_feedback_screen.dart';
import 'client_next_appointments_screen.dart';
import 'training_recording_screen.dart';

class ClientDetailScreen extends StatefulWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  final ApiService _apiService = ApiService();
  late bool _autoNotify;
  bool _togglingNotify = false;

  Client get client => widget.client;

  @override
  void initState() {
    super.initState();
    _autoNotify = widget.client.autoTrainingNotify;
    _loadNotifySetting();
  }

  Future<void> _loadNotifySetting() async {
    try {
      final resp = await _apiService.get(
        '${ApiConfig.client}/${widget.client.id}/auto-notify',
      );
      if (resp is Map && mounted) {
        setState(() {
          _autoNotify = (resp['enabled'] ?? 0) == 1;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleAutoNotify(bool value) async {
    setState(() => _togglingNotify = true);
    try {
      await _apiService.put(
        '${ApiConfig.client}/${widget.client.id}/auto-notify',
        body: {'enabled': value ? 1 : 0},
      );
      if (mounted) setState(() => _autoNotify = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fehler: $e'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingNotify = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();

    // Filter trainings for this client
    final clientTrainings = trainerProvider.trainings
        .where((t) => t.clientId == client.id || t.clientName == client.name)
        .toList();

    final upcomingTrainings = clientTrainings
        .where((t) =>
            !t.isCancelled &&
            t.startTime != null &&
            t.startTime!.isAfter(DateTime.now()))
        .toList();

    final pastTrainings = clientTrainings
        .where((t) =>
            t.startTime == null || t.startTime!.isBefore(DateTime.now()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(),
                _buildContactInfo(),
                if (upcomingTrainings.isNotEmpty)
                  _buildTrainingsSection(
                      context, 'Anstehende Termine', upcomingTrainings, true),
                if (pastTrainings.isNotEmpty)
                  _buildTrainingsSection(
                      context, 'Vergangene Termine', pastTrainings, false),
                if (clientTrainings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_note_outlined,
                              color: AppColors.muted, size: 48),
                          SizedBox(height: 12),
                          Text(
                            'Keine Trainings gefunden',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildAutoNotifyToggle(),
                _buildQuickActions(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: AppColors.background,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          client.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.background],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (client.trainingType != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Text(
                        client.trainingType!,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  if (client.memberSince != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Member since ${client.memberSince}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (client.photo != null && client.photo!.isNotEmpty) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: AppColors.border,
        backgroundImage: NetworkImage(client.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: AppColors.primary.withAlpha(40),
      child: Text(
        client.initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    final hasContact = client.email != null ||
        client.phone != null ||
        client.address != null ||
        client.dateOfBirth != null;

    if (!hasContact) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Information',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            if (client.email != null)
              _ContactRow(
                  icon: Icons.email_outlined, text: client.email!),
            if (client.phone != null)
              _ContactRow(icon: Icons.phone_outlined, text: client.phone!),
            if (client.address != null)
              _ContactRow(
                  icon: Icons.location_on_outlined, text: client.address!),
            if (client.dateOfBirth != null)
              _ContactRow(
                  icon: Icons.cake_outlined, text: client.dateOfBirth!),
            if (client.notes != null && client.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 8),
              const Text(
                'Notizen',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                client.notes!,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAutoNotifyToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _autoNotify
                ? AppColors.primary.withAlpha(60)
                : AppColors.border,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _autoNotify
                    ? AppColors.primary.withAlpha(30)
                    : AppColors.border.withAlpha(50),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.notifications_active_outlined,
                color: _autoNotify ? AppColors.primary : AppColors.muted,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Auto-Benachrichtigung',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _autoNotify
                        ? 'Training-Report nach jedem Workout'
                        : 'Benachrichtigungen deaktiviert',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (_togglingNotify)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              Switch(
                value: _autoNotify,
                onChanged: _toggleAutoNotify,
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withAlpha(80),
                inactiveThumbColor: AppColors.muted,
                inactiveTrackColor: AppColors.border,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.assignment_outlined,
        label: 'Anamnese',
        subtitle: 'Fragebogen',
        color: AppColors.primary,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AnamneseScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.table_chart_outlined,
        label: 'Trainingsplan',
        subtitle: 'Pläne & Übungen',
        color: AppColors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TrainingPlanListScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.show_chart,
        label: 'Leistung',
        subtitle: 'Verlauf',
        color: AppColors.green,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PerformanceScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.monitor_heart_outlined,
        label: 'Aufzeichnung',
        subtitle: 'Herzfrequenz',
        color: AppColors.red,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => TrainingRecordingScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.event_available,
        label: 'Termine',
        subtitle: 'Nächste Sessions',
        color: const Color(0xFF9C27B0),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ClientNextAppointmentsScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.chat_bubble_outline,
        label: 'Nachrichten',
        subtitle: 'Chat & Feedback',
        color: const Color(0xFF26A69A),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => WorkoutFeedbackScreen(client: client)),
        ),
      ),
      _QuickAction(
        icon: Icons.folder_outlined,
        label: 'Dateien',
        subtitle: 'Dokumente',
        color: const Color(0xFF00897B),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ClientFilesScreen(client: client)),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Aktionen',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: actions
                .map((a) => _QuickActionTile(action: a))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingsSection(BuildContext context, String title,
      List<Training> trainings, bool upcoming) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                upcoming ? Icons.upcoming : Icons.history,
                color: upcoming
                    ? AppColors.primary
                    : AppColors.muted,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trainings.length.toString(),
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...trainings
              .take(upcoming ? 5 : 3)
              .map((t) => _TrainingItem(training: t, upcoming: upcoming)),
          if (upcoming && trainings.length > 5)
            TextButton(
              onPressed: () {},
              child: Text('Alle ${trainings.length} Termine anzeigen'),
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingItem extends StatefulWidget {
  final Training training;
  final bool upcoming;

  const _TrainingItem({required this.training, this.upcoming = false});

  @override
  State<_TrainingItem> createState() => _TrainingItemState();
}

class _TrainingItemState extends State<_TrainingItem> {
  final ApiService _apiService = ApiService();
  bool _isCancelling = false;
  late Training _training;

  @override
  void initState() {
    super.initState();
    _training = widget.training;
  }

  Future<void> _cancelTraining() async {
    final authProvider = context.read<AuthProvider>();
    final trainer = authProvider.trainer;
    if (trainer == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Training absagen',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Möchtest du dieses Training wirklich absagen?',
          style: TextStyle(color: AppColors.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nein',
                style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja, absagen',
                style: TextStyle(color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await _apiService.post('${ApiConfig.training}/${_training.id}/cancel');
      if (mounted) {
        setState(() {
          _training = Training(
            id: _training.id,
            title: _training.title,
            startTime: _training.startTime,
            endTime: _training.endTime,
            date: _training.date,
            timeFrom: _training.timeFrom,
            timeTo: _training.timeTo,
            clientId: _training.clientId,
            clientName: _training.clientName,
            trainerId: _training.trainerId,
            trainerName: _training.trainerName,
            locationId: _training.locationId,
            locationName: _training.locationName,
            trainingType: _training.trainingType,
            status: 'cancelled',
            notes: _training.notes,
            isCancelled: true,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Training cancelled successfully.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainingDetailScreen(training: _training),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _training.isCancelled
                        ? AppColors.muted
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _training.displayDate,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _training.displayTime,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_training.locationName != null)
                  Text(
                    _training.locationName!,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                if (_training.isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cancelled',
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ] else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.muted,
                    size: 18,
                  ),
              ],
            ),
            if (!_training.isCancelled && widget.upcoming) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelTraining,
                  icon: _isCancelling
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary),
                        )
                      : const Icon(Icons.cancel_outlined, size: 15),
                  label: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel Training',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(
                        color: AppColors.primary, width: 0.8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: action.color.withOpacity(0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: action.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(action.icon, color: action.color, size: 22),
            ),
            const SizedBox(height: 7),
            Text(
              action.label,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (action.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                action.subtitle!,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
