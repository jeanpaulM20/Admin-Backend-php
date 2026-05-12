import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/training.dart';
import '../config/app_colors.dart';
import 'training_detail_screen.dart';
import 'training_analytics_screen.dart';

class TrainingsScreen extends StatefulWidget {
  const TrainingsScreen({super.key});

  @override
  State<TrainingsScreen> createState() => _TrainingsScreenState();
}

class _TrainingsScreenState extends State<TrainingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _currentTab) {
        setState(() => _currentTab = _tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Training> _upcoming(List<Training> all) {
    final now = DateTime.now();
    return all
        .where((t) =>
            !t.isCancelled &&
            t.startTime != null &&
            t.startTime!.isAfter(now))
        .where(_matchesSearch)
        .toList()
      ..sort((a, b) => a.startTime!.compareTo(b.startTime!));
  }

  List<Training> _past(List<Training> all) {
    final now = DateTime.now();
    return all
        .where((t) =>
            t.startTime == null || t.startTime!.isBefore(now))
        .where(_matchesSearch)
        .toList()
      ..sort((a, b) {
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });
  }

  bool _matchesSearch(Training t) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    // Search across all relevant fields
    if (t.clientName?.toLowerCase().contains(q) ?? false) return true;
    if (t.title?.toLowerCase().contains(q) ?? false) return true;
    if (t.trainingType?.toLowerCase().contains(q) ?? false) return true;
    if (t.locationName?.toLowerCase().contains(q) ?? false) return true;
    if (t.trainerName?.toLowerCase().contains(q) ?? false) return true;
    if (t.notes?.toLowerCase().contains(q) ?? false) return true;
    // Date search: "15.03", "März", "2025" etc.
    if (t.startTime != null) {
      final formatted = DateFormat('dd.MM.yyyy').format(t.startTime!);
      if (formatted.contains(q)) return true;
      // German month names
      final monthDe = DateFormat('MMMM', 'de_DE').format(t.startTime!).toLowerCase();
      if (monthDe.contains(q)) return true;
      // Day name (e.g. "Montag")
      final dayDe = DateFormat('EEEE', 'de_DE').format(t.startTime!).toLowerCase();
      if (dayDe.contains(q)) return true;
    }
    // Status search: "abgesagt", "absolviert", "gebucht", "verpasst"
    final status = (t.status ?? '').toLowerCase();
    if (t.isCancelled || status == 'cancelled' || status == 'canceled') {
      if ('abgesagt'.contains(q)) return true;
    } else if (status == 'attended') {
      if ('absolviert'.contains(q)) return true;
    } else if (status == 'missed') {
      if ('verpasst'.contains(q)) return true;
    } else {
      if ('gebucht'.contains(q)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();
    final authProvider = context.watch<AuthProvider>();
    final trainer = authProvider.trainer;
    final all = trainerProvider.trainings;
    final upcoming = _upcoming(all);
    final past = _past(all);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trainings'),
        actions: [
          if (trainer != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => trainerProvider.fetchTrainings(trainer.id),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Upcoming'),
                  if (upcoming.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: upcoming.length),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Vergangen'),
                  if (past.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _Badge(count: past.length, muted: true),
                  ],
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bar_chart_rounded, size: 16),
                  SizedBox(width: 4),
                  Text('Statistik'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Hide search bar on Statistik tab (it has its own time range filter)
          if (_currentTab != 2) _buildSearchBar(),
          Expanded(
            child: trainerProvider.trainingsLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2,
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _TrainingList(
                        trainings: upcoming,
                        emptyIcon: Icons.event_available,
                        emptyText: 'Keine anstehenden Trainings',
                        onRefresh: trainer != null
                            ? () => trainerProvider.fetchTrainings(trainer.id)
                            : null,
                      ),
                      _TrainingList(
                        trainings: past,
                        emptyIcon: Icons.history,
                        emptyText: 'Keine vergangenen Trainings',
                        onRefresh: trainer != null
                            ? () => trainerProvider.fetchTrainings(trainer.id)
                            : null,
                      ),
                      TrainingAnalytics(trainings: all),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppColors.text),
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Kunde, Typ oder Ort suchen...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  final bool muted;

  const _Badge({required this.count, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: muted ? AppColors.surface2 : AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: muted ? AppColors.border : AppColors.primary.withOpacity(0.4),
        ),
      ),
      child: Text(
        count.toString(),
        style: TextStyle(
          color: muted ? AppColors.muted : AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TrainingList extends StatelessWidget {
  final List<Training> trainings;
  final IconData emptyIcon;
  final String emptyText;
  final Future<void> Function()? onRefresh;

  const _TrainingList({
    required this.trainings,
    required this.emptyIcon,
    required this.emptyText,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (trainings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(emptyText,
                style: const TextStyle(color: AppColors.muted, fontSize: 15)),
          ],
        ),
      );
    }

    final listView = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: trainings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _TrainingCard(training: trainings[i]),
    );

    if (onRefresh != null) {
      return RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: listView,
      );
    }
    return listView;
  }
}

class _TrainingCard extends StatelessWidget {
  final Training training;

  const _TrainingCard({required this.training});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TrainingDetailScreen(training: training),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: training.isCancelled
                ? AppColors.border
                : AppColors.primary.withOpacity(0.25),
          ),
        ),
        child: Row(
          children: [
            // Left accent bar
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: training.isCancelled
                    ? AppColors.muted.withOpacity(0.3)
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            // Date box
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: training.isCancelled
                    ? AppColors.surface2
                    : AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: training.startTime != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(training.startTime!),
                          style: TextStyle(
                            color: training.isCancelled
                                ? AppColors.muted
                                : AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(training.startTime!),
                          style: TextStyle(
                            color: training.isCancelled
                                ? AppColors.muted
                                : AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    )
                  : const Icon(Icons.event, color: AppColors.muted, size: 22),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    training.clientName ?? training.title ?? 'Training',
                    style: TextStyle(
                      color: training.isCancelled
                          ? AppColors.muted
                          : AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: training.isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.access_time,
                          size: 12, color: AppColors.muted),
                      const SizedBox(width: 3),
                      Text(
                        training.displayTime,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                      if (training.locationName != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            training.locationName!,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Type badge / cancelled badge
            if (training.isCancelled)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Abgesagt',
                    style:
                        TextStyle(color: AppColors.muted, fontSize: 11)),
              )
            else if (training.trainingType != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.primary.withOpacity(0.25)),
                ),
                child: Text(
                  training.trainingType!,
                  style: const TextStyle(
                      color: AppColors.primary, fontSize: 11),
                ),
              )
            else
              const Icon(Icons.chevron_right,
                  color: AppColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
