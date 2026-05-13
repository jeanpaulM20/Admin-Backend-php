import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/training.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class TrainingDetailScreen extends StatefulWidget {
  final Training training;

  const TrainingDetailScreen({super.key, required this.training});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            child:
                const Text('Nein', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ja, absagen',
              style: TextStyle(color: Color(0xFFB71C1C)),
            ),
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
            content: Text('Training wurde abgesagt.'),
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

  Future<void> _addToCalendar() async {
    final id = _training.id;
    if (id == null) return;

    final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.training}/$id/ical');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kalender-Download konnte nicht geöffnet werden.'),
            backgroundColor: AppColors.red,
          ),
        );
      }
    }
  }

  Color get _statusColor {
    final s = (_training.status ?? '').toLowerCase();
    if (s == 'attended') return const Color(0xFF2E7D32);
    if (s == 'booked') return AppColors.primary;
    if (s == 'cancelled' || s == 'canceled' || _training.isCancelled) {
      return AppColors.red;
    }
    if (s == 'missed') return AppColors.orange;
    return AppColors.primary;
  }

  String get _statusLabel {
    if (_training.isCancelled) return 'Abgesagt';
    final s = (_training.status ?? '').toLowerCase();
    if (s == 'attended') return 'Absolviert';
    if (s == 'booked') return 'Gebucht';
    if (s == 'missed') return 'Verpasst';
    if (s.isEmpty) return 'Geplant';
    return _training.status ?? 'Unbekannt';
  }

  IconData get _statusIcon {
    if (_training.isCancelled) return Icons.cancel_outlined;
    final s = (_training.status ?? '').toLowerCase();
    if (s == 'attended') return Icons.check_circle_outline;
    if (s == 'missed') return Icons.error_outline;
    return Icons.schedule_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Training-Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusBanner(),
            const SizedBox(height: 16),
            _buildDetailCard(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: _statusColor.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _statusColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(_statusIcon, color: _statusColor, size: 22),
          const SizedBox(width: 12),
          Text(
            _statusLabel,
            style: TextStyle(
              color: _statusColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Termininfo',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Datum',
            value: _training.displayDate,
          ),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Uhrzeit',
            value: _training.displayTime,
          ),
          if (_training.clientName != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Kunde',
              value: _training.clientName!,
            ),
          if (_training.trainingType != null)
            _DetailRow(
              icon: Icons.fitness_center_outlined,
              label: 'Typ',
              value: _training.trainingType!,
            ),
          if (_training.locationName != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Ort',
              value: _training.locationName!,
            ),
          if (_training.notes != null && _training.notes!.isNotEmpty)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Notizen',
              value: _training.notes!,
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Add to calendar ──
        ElevatedButton.icon(
          onPressed: _addToCalendar,
          icon: const Icon(Icons.calendar_month_outlined, size: 18),
          label: const Text('Zum Kalender hinzufügen'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // ── Cancel training ──
        if (!_training.isCancelled) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isCancelling ? null : _cancelTraining,
            icon: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.red),
                  )
                : const Icon(Icons.cancel_outlined, size: 18),
            label: Text(
                _isCancelling ? 'Wird abgesagt...' : 'Training absagen'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.red,
              side: const BorderSide(color: AppColors.red),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
