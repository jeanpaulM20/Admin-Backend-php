import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client.dart';
import '../models/training.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import 'training_detail_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  final Client client;

  const ClientDetailScreen({super.key, required this.client});

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
      backgroundColor: const Color(0xFF1a1a1a),
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
                      context, 'Upcoming Sessions', upcomingTrainings, true),
                if (pastTrainings.isNotEmpty)
                  _buildTrainingsSection(
                      context, 'Past Sessions', pastTrainings, false),
                if (clientTrainings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.event_note_outlined,
                              color: Color(0xFF555555), size: 48),
                          SizedBox(height: 12),
                          Text(
                            'No training sessions found',
                            style: TextStyle(color: Color(0xFF9E9E9E)),
                          ),
                        ],
                      ),
                    ),
                  ),
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
      backgroundColor: const Color(0xFF1a1a1a),
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
              colors: [Color(0xFF2a1010), Color(0xFF1a1a1a)],
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
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF333333), width: 0.5),
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
                        color: const Color(0xFF8B2020).withAlpha(30),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF8B2020).withAlpha(60)),
                      ),
                      child: Text(
                        client.trainingType!,
                        style: const TextStyle(
                          color: Color(0xFFB03030),
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
                          color: Color(0xFF9E9E9E), fontSize: 12),
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
        backgroundColor: const Color(0xFF333333),
        backgroundImage: NetworkImage(client.photo!),
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 36,
      backgroundColor: const Color(0xFF8B2020).withAlpha(40),
      child: Text(
        client.initials,
        style: const TextStyle(
          color: Color(0xFFB03030),
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
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF333333), width: 0.5),
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
              const Divider(color: Color(0xFF333333), height: 1),
              const SizedBox(height: 8),
              const Text(
                'Notes',
                style: TextStyle(
                    color: Color(0xFF9E9E9E),
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                client.notes!,
                style: const TextStyle(
                  color: Color(0xFFBBBBBB),
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
                    ? const Color(0xFF8B2020)
                    : const Color(0xFF555555),
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
                  color: const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trainings.length.toString(),
                  style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 12),
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
              child: Text('View all ${trainings.length} sessions'),
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
          Icon(icon, size: 16, color: const Color(0xFF9E9E9E)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
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
        backgroundColor: const Color(0xFF252525),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
            child: const Text('No',
                style: TextStyle(color: Color(0xFF9E9E9E))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Cancel',
                style: TextStyle(color: Color(0xFFB71C1C))),
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
          'id': _training.id.toString(),
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
          color: const Color(0xFF252525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF333333), width: 0.5),
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
                        ? const Color(0xFF555555)
                        : const Color(0xFF8B2020),
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
                          color: Color(0xFF9E9E9E),
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
                        color: Color(0xFF777777), fontSize: 12),
                  ),
                if (_training.isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Cancelled',
                      style: TextStyle(
                          color: Color(0xFF777777), fontSize: 11),
                    ),
                  ),
                ] else
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF555555),
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
                              color: Color(0xFF8B2020)),
                        )
                      : const Icon(Icons.cancel_outlined, size: 15),
                  label: Text(
                    _isCancelling ? 'Cancelling...' : 'Cancel Training',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B2020),
                    side: const BorderSide(
                        color: Color(0xFF8B2020), width: 0.8),
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
