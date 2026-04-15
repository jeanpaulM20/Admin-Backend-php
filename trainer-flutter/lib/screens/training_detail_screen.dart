import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/training.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';

class TrainingDetailScreen extends StatefulWidget {
  final Training training;

  const TrainingDetailScreen({super.key, required this.training});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  final ApiService _apiService = ApiService();
  bool _isCancelling = false;
  bool _isInviting = false;
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
        backgroundColor: const Color(0xFF252525),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Cancel Training',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to cancel this training session?',
          style: TextStyle(color: Color(0xFFCCCCCC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Color(0xFFB71C1C)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await _apiService.postForm(
        ApiConfig.cancelTrainingTrainer,
        body: {
          'trainer_id': trainer.id.toString(),
          'training_id': _training.id.toString(),
        },
      );
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
            backgroundColor: const Color(0xFF8B2020),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _inviteTraining() async {
    final authProvider = context.read<AuthProvider>();
    final trainer = authProvider.trainer;
    if (trainer == null) return;

    setState(() => _isInviting = true);
    try {
      await _apiService.postForm(
        ApiConfig.inviteTrainingTrainer,
        body: {
          'trainer_id': trainer.id.toString(),
          'training_id': _training.id.toString(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invite sent successfully.'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: const Color(0xFF8B2020),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Color get _statusColor {
    final s = (_training.status ?? '').toLowerCase();
    if (s == 'confirmed') return const Color(0xFF2E7D32);
    if (s == 'cancelled' || s == 'canceled' || _training.isCancelled) {
      return const Color(0xFF555555);
    }
    return const Color(0xFF8B6020);
  }

  String get _statusLabel {
    if (_training.isCancelled) return 'Cancelled';
    final s = (_training.status ?? '').toLowerCase();
    if (s == 'confirmed') return 'Confirmed';
    if (s == 'pending') return 'Pending';
    if (s.isEmpty) return 'Scheduled';
    return (_training.status ?? 'Unknown');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1a1a),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Training Details',
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
            if (!_training.isCancelled) _buildActionButtons(),
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
          Icon(
            _training.isCancelled
                ? Icons.cancel_outlined
                : (_training.status?.toLowerCase() == 'confirmed'
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined),
            color: _statusColor,
            size: 22,
          ),
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
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF333333), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Info',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Date',
            value: _training.displayDate,
          ),
          _DetailRow(
            icon: Icons.access_time_outlined,
            label: 'Time',
            value: _training.displayTime,
          ),
          if (_training.clientName != null)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Client',
              value: _training.clientName!,
            ),
          if (_training.trainingType != null)
            _DetailRow(
              icon: Icons.fitness_center_outlined,
              label: 'Type',
              value: _training.trainingType!,
            ),
          if (_training.locationName != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: _training.locationName!,
            ),
          if (_training.notes != null && _training.notes!.isNotEmpty)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Notes',
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
        ElevatedButton.icon(
          onPressed: _isInviting ? null : _inviteTraining,
          icon: _isInviting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_outlined, size: 18),
          label: Text(_isInviting ? 'Sending...' : 'Invite Training'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8B2020),
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
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _isCancelling ? null : _cancelTraining,
          icon: _isCancelling
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF8B2020)),
                )
              : const Icon(Icons.cancel_outlined, size: 18),
          label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Training'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF8B2020),
            side: const BorderSide(color: Color(0xFF8B2020)),
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
          Icon(icon, size: 17, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9E9E9E),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
