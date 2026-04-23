import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/trainer_provider.dart';
import '../models/training.dart';
import '../config/app_colors.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedPeriod = 1; // 0=week, 1=month, 2=year

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
    _tabController.addListener(() {
      setState(() => _selectedPeriod = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Training> _getFilteredTrainings(List<Training> trainings) {
    final now = DateTime.now();
    DateTime from;
    switch (_selectedPeriod) {
      case 0:
        from = now.subtract(const Duration(days: 7));
        break;
      case 1:
        from = DateTime(now.year, now.month, 1);
        break;
      case 2:
        from = DateTime(now.year, 1, 1);
        break;
      default:
        from = DateTime(now.year, now.month, 1);
    }

    return trainings.where((t) {
      if (t.startTime == null) return false;
      return t.startTime!.isAfter(from) && t.startTime!.isBefore(now);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final trainerProvider = context.watch<TrainerProvider>();
    final authProvider = context.watch<AuthProvider>();
    final trainer = authProvider.trainer;
    final allTrainings = trainerProvider.trainings;
    final filtered = _getFilteredTrainings(allTrainings);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Training Review'),
        actions: [
          if (trainer != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () =>
                  trainerProvider.fetchTrainings(trainer.id),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'This Week'),
            Tab(text: 'This Month'),
            Tab(text: 'This Year'),
          ],
        ),
      ),
      body: trainerProvider.trainingsLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: () async {
                if (trainer != null) {
                  await trainerProvider.fetchTrainings(trainer.id);
                }
              },
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSummaryCards(filtered, allTrainings),
                  const SizedBox(height: 20),
                  if (filtered.isNotEmpty) ...[
                    _buildSessionsChart(filtered),
                    const SizedBox(height: 20),
                    _buildTypeBreakdown(filtered),
                    const SizedBox(height: 20),
                  ],
                  _buildRecentSessions(filtered),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryCards(
      List<Training> filtered, List<Training> all) {
    final completed =
        filtered.where((t) => !t.isCancelled).length;
    final cancelled =
        filtered.where((t) => t.isCancelled).length;
    final totalAllTime = all.where((t) => !t.isCancelled).length;
    final completionRate =
        filtered.isNotEmpty ? (completed / filtered.length * 100).round() : 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Sessions',
                value: completed.toString(),
                icon: Icons.fitness_center,
                color: AppColors.primary,
                subtitle: _getPeriodLabel(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'Completion',
                value: '$completionRate%',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                subtitle: 'rate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Cancelled',
                value: cancelled.toString(),
                icon: Icons.cancel_outlined,
                color: AppColors.muted,
                subtitle: _getPeriodLabel(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryCard(
                label: 'All Time',
                value: totalAllTime.toString(),
                icon: Icons.history,
                color: const Color(0xFF1565C0),
                subtitle: 'total sessions',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getPeriodLabel() {
    switch (_selectedPeriod) {
      case 0:
        return 'this week';
      case 1:
        return 'this month';
      case 2:
        return 'this year';
      default:
        return '';
    }
  }

  Widget _buildSessionsChart(List<Training> trainings) {
    // Build daily session counts
    final Map<String, int> dayCounts = {};
    for (final t in trainings) {
      if (t.startTime == null || t.isCancelled) continue;
      final key = DateFormat('MM/dd').format(t.startTime!);
      dayCounts[key] = (dayCounts[key] ?? 0) + 1;
    }

    if (dayCounts.isEmpty) return const SizedBox.shrink();

    final sortedKeys = dayCounts.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), dayCounts[e.value]!.toDouble());
    }).toList();

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
          const Text(
            'Sessions Over Time',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                backgroundColor: Colors.transparent,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.border,
                    strokeWidth: 0.5,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, _) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: spots.length > 8
                          ? (spots.length / 4).ceilToDouble()
                          : 1,
                      getTitlesWidget: (value, _) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < sortedKeys.length) {
                          return Text(
                            sortedKeys[idx],
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 10),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: spots.length <= 14,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primary,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withAlpha(60),
                          AppColors.primary.withAlpha(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeBreakdown(List<Training> trainings) {
    final Map<String, int> typeCounts = {};
    for (final t in trainings) {
      if (t.isCancelled) continue;
      final type = t.trainingType ?? 'Unknown';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
    }

    if (typeCounts.isEmpty) return const SizedBox.shrink();

    final total = typeCounts.values.fold(0, (a, b) => a + b);
    final colors = [
      AppColors.primary,
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFE65100),
    ];

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
          const Text(
            'Training Types',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...typeCounts.entries.toList().asMap().entries.map((entry) {
            final idx = entry.key;
            final name = entry.value.key;
            final count = entry.value.value;
            final pct = (count / total * 100).round();
            final color = colors[idx % colors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                              color: AppColors.text, fontSize: 13),
                        ),
                      ),
                      Text(
                        '$count ($pct%)',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: count / total,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentSessions(List<Training> trainings) {
    if (trainings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: const Center(
          child: Column(
            children: [
              Icon(Icons.fitness_center, color: AppColors.muted, size: 44),
              SizedBox(height: 12),
              Text(
                'No sessions in this period',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    // Sort most recent first
    final sorted = List<Training>.from(trainings)
      ..sort((a, b) {
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Sessions',
          style: TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...sorted.take(10).map((t) => _ReviewTrainingItem(training: t)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ReviewTrainingItem extends StatelessWidget {
  final Training training;

  const _ReviewTrainingItem({required this.training});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: training.isCancelled
                  ? AppColors.border
                  : AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              training.isCancelled
                  ? Icons.cancel_outlined
                  : Icons.fitness_center,
              color: training.isCancelled
                  ? AppColors.muted
                  : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  training.clientName ?? training.title ?? 'Session',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${training.displayDate} · ${training.displayTime}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (training.trainingType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                training.trainingType!,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ),
          if (training.isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Cancelled',
                style: TextStyle(color: AppColors.primary, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
